/* =============================================================
   Proyecto IF0010 - Sistema de Facturación Propi
   03 - Cifrado columnar de datos sensibles (REQ 006)
   -------------------------------------------------------------
   Jerarquía de llaves de SQL Server:
     Service Master Key (la crea SQL Server al instalarse)
       -> Database Master Key (protege al certificado)
         -> Certificado cert_clientes (protege a la llave simétrica)
           -> Llave simétrica llave_clientes AES_256 (cifra los datos)
   Los datos se cifran con ENCRYPTBYKEY y se leen con DECRYPTBYKEY
   dentro de los procedimientos almacenados de clientes.
   IMPORTANTE: respaldar el certificado y la master key (ver DRP);
   sin ellos los datos cifrados no se pueden recuperar.
   ============================================================= */
USE PropiFacturacion_AAMM;
GO

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Propi#MasterKey2026';
GO

IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'cert_clientes')
    CREATE CERTIFICATE cert_clientes
        WITH SUBJECT = 'Cifrado de datos sensibles de clientes';
GO

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = 'llave_clientes')
    CREATE SYMMETRIC KEY llave_clientes
        WITH ALGORITHM = AES_256
        ENCRYPTION BY CERTIFICATE cert_clientes;
GO
