#Proyecto IF0010 - Sistema de Facturación Propi
#21 - Prueba de RPO y RTO de la réplica (REQ 014)
#Requisitos: 16_respaldos.sql en la principal y 20_replica_secundaria.sql en la secundaria
#Hace el papel de los trabajos del Agente (log cada 30 s en la principal, aplicar logs cada 15 s en la secundaria),
#inserta un registro por segundo en la principal, mide cuánto tarda en verse en la secundaria,
#pone la principal fuera de línea, activa la secundaria y mide el RTO y los datos perdidos
#Uso: powershell -ExecutionPolicy Bypass -File 21_prueba_replica.ps1 -Segundos 200
#OJO: deja la base principal OFFLINE; para volver: ALTER DATABASE PropiFacturacion_AAMM SET ONLINE;
param([int]$Segundos = 200,
      [string]$Principal = 'localhost\SQLSERVERPT',
      [string]$Secundaria = 'localhost\SQLSERVERSJ')
$ErrorActionPreference = 'Stop'
$out = Join-Path (Get-Location) 'prueba_replica.log'
function Log($m) { $l = "{0:HH:mm:ss.fff} {1}" -f (Get-Date), $m; Add-Content -Path $out -Value $l -Encoding utf8 }
function Run($srv, $db, $sql, [switch]$Scalar, $user, $pass) {
    $cs = if ($user) { "Server=$srv;Database=$db;User ID=$user;Password=$pass;Pooling=false;Connect Timeout=5" } else { "Server=$srv;Database=$db;Integrated Security=true;Pooling=false;Connect Timeout=5" }
    $cn = New-Object System.Data.SqlClient.SqlConnection $cs
    $cn.Open()
    try {
        $cmd = $cn.CreateCommand(); $cmd.CommandText = $sql; $cmd.CommandTimeout = 120
        if ($Scalar) { return $cmd.ExecuteScalar() } else { [void]$cmd.ExecuteNonQuery() }
    } finally { $cn.Close() }
}
$P = $Principal; $S = $Secundaria; $B = 'PropiFacturacion_AAMM'
Set-Content -Path $out -Value '' -Encoding utf8
Log "inicio prueba, $Segundos s de carga"

$latencias = @(); $pendientes = @{}
$ultimoInsertado = 0; $ultimoInsertadoHora = $null
for ($t = 1; $t -le $Segundos; $t++) {
    $tick = Get-Date
    #Carga: un registro por segundo en la principal
    $id = Run $P $B "INSERT INTO auditoria.bitacora_acceso (nom_usuario, nom_terminal, fec_ingreso) OUTPUT inserted.cod_acceso VALUES ('prueba_rpo', 'PC-RPO', SYSDATETIME());" -Scalar
    $ultimoInsertado = [int]$id; $ultimoInsertadoHora = Get-Date
    $pendientes[$ultimoInsertado] = $ultimoInsertadoHora
    #Agente de la principal: respaldo de log cada 30 s
    if ($t % 30 -eq 0) { Run $P $B "EXEC dbo.pa_respaldar 'LOG', N'C:\PropiRespaldos\';"; Log "principal: respaldo de log" }
    #Agente de la secundaria: aplicar logs cada 15 s
    if ($t % 15 -eq 0) { Run $S 'master' "EXEC dbo.pa_replica_aplicar_logs;"; Log "secundaria: logs aplicados" }
    #Qué ya se ve en la secundaria
    try {
        $max = Run $S $B "SELECT ISNULL(MAX(cod_acceso), 0) FROM auditoria.bitacora_acceso WHERE nom_usuario = 'prueba_rpo';" -Scalar
        foreach ($k in @($pendientes.Keys)) { if ($k -le [int]$max) { $latencias += ((Get-Date) - $pendientes[$k]).TotalSeconds; $pendientes.Remove($k) } }
    } catch { }
    $espera = 1000 - ((Get-Date) - $tick).TotalMilliseconds
    if ($espera -gt 0) { Start-Sleep -Milliseconds $espera }
}
$lat = $latencias | Measure-Object -Average -Maximum -Minimum
Log ("latencia de replicacion (s): registros={0} promedio={1:N1} min={2:N1} max={3:N1}" -f $lat.Count, $lat.Average, $lat.Minimum, $lat.Maximum)

#Falla de la principal: la base queda fuera de línea
$fallo = Get-Date
Run $P 'master' "ALTER DATABASE $B SET OFFLINE WITH ROLLBACK IMMEDIATE;"
Log "FALLA: principal fuera de linea. Ultimo registro confirmado en la principal: $ultimoInsertado a las $('{0:HH:mm:ss.fff}' -f $ultimoInsertadoHora)"

#Conmutación
$a = Get-Date
Run $S 'master' "EXEC dbo.pa_replica_activar;"
Log ("secundaria activada en {0:N1} s" -f ((Get-Date) - $a).TotalSeconds)

#La aplicación vuelve a operar: login técnico + EXECUTE AS como el backend
$sql = "EXECUTE AS USER = 'propi_digitador'; EXEC facturacion.pa_clientes_consultar 1; REVERT; SELECT 1;"
$ok = Run $S $B $sql -Scalar -user 'propi_app' -pass 'PropiApp#2026'
$operativo = Get-Date
Log ("aplicacion operando en la secundaria (resultado $ok). RTO medido = {0:N1} s" -f ($operativo - $fallo).TotalSeconds)

#Pérdida de datos
$enSec = [int](Run $S $B "SELECT ISNULL(MAX(cod_acceso), 0) FROM auditoria.bitacora_acceso WHERE nom_usuario = 'prueba_rpo';" -Scalar)
$horaSec = Run $S $B "SELECT MAX(fec_ingreso) FROM auditoria.bitacora_acceso WHERE cod_acceso = $enSec;" -Scalar
$horaPri = $ultimoInsertadoHora
Log ("ultimo registro en la secundaria: $enSec ({0:HH:mm:ss.fff}). Registros perdidos: {1}. RPO medido = {2:N1} s" -f $horaSec, ($ultimoInsertado - $enSec), ($horaPri - $horaSec).TotalSeconds)

#Escritura en la secundaria
$w = Run $S $B "EXECUTE AS USER = 'propi_admin'; DECLARE @f INT = (SELECT MAX(cod_factura) FROM facturacion.facturas); EXEC facturacion.pa_notas_insertar @f, 2, 'Prueba de escritura tras conmutacion', 1; REVERT; SELECT COUNT(*) FROM facturacion.notas_credito_debito WHERE des_motivo LIKE 'Prueba de escritura%';" -Scalar -user 'propi_app' -pass 'PropiApp#2026'
Log "escritura en la secundaria por procedimiento: notas de prueba = $w"
Log "fin"
