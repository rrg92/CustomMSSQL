CREATE USER Estag
go
GRANT SELECT TO Estag;
go

EXEC sp_addrolemember 'db_datawriter','Estag'
go
CREATE SYMMETRIC KEY smkTest WITH ALGORITHM = DES ENCRYPTION BY PASSWORD = '0r3u0runfonvu'
go

CREATE CERTIFICATE certTest ENCRYPTION BY PASSWORD = '	2er83q47r38470' WITH SUBJECT = 'Copy-SQLDatabase tests'  
go

GRANT CONTROL ON SYMMETRIC KEY::smkTest TO Estag;
go

GRANT CONTROL ON CERTIFICATE::certTest TO Estag;
go

GRANT ALTER ON SCHEMA::schema2 TO Estag;
go

GRANT CONTROL ON USER::dbo TO Estag;
go

CREATE ROLE Test1;
go

EXEC sp_addrolemember 'Test1','Estag';
go

GRANT CONTROL ON OBJECT::QueryNotificationErrorsQueue TO Test1;
go


ALTER AUTHORIZATION ON DATABASE::DestCopy TO [DemoOnwer]
go