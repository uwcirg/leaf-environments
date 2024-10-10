-- MariaDB initialization script; run on first start only
CREATE DATABASE IF NOT EXISTS radar;
GRANT SELECT, CREATE TEMPORARY TABLES ON radar.* TO `db-user`@`%`;
