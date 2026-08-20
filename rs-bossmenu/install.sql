CREATE TABLE IF NOT EXISTS `rs_company_accounts` (
    `job_name` VARCHAR(50) NOT NULL,
    `balance` BIGINT NOT NULL DEFAULT 0,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`job_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rs_bossmenu_logs` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `job_name` VARCHAR(50) NOT NULL,
    `identifier` VARCHAR(100) NULL,
    `actor_identifier` VARCHAR(100) NULL,
    `action` VARCHAR(100) NOT NULL,
    `details` LONGTEXT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_job_created` (`job_name`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
