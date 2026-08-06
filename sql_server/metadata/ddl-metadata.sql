
USE b2b_source_db;
GO

CREATE SCHEMA metadata;
GO

CREATE TABLE metadata.Generation_Seeds
(
    generation_id INT IDENTITY(1,1) PRIMARY KEY,
    generator_name VARCHAR(50) NOT NULL,
    seed BIGINT NOT NULL,
    description VARCHAR(200),
    generated_at DATETIME2 DEFAULT GETDATE()
);