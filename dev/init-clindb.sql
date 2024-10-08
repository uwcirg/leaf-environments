-- MariaDB initialization script; run on first start only
CREATE DATABASE IF NOT EXISTS radar;
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON radar TO 'db-user'@'localhost';
