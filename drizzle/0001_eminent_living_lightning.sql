CREATE TABLE `targets` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`name` text NOT NULL,
	`host` text NOT NULL,
	`ssh_user` text DEFAULT 'root' NOT NULL,
	`ssh_port` integer DEFAULT 22 NOT NULL,
	`root_path` text DEFAULT '/opt/apps' NOT NULL,
	`auth_type` text DEFAULT 'password' NOT NULL,
	`password` text,
	`private_key` text,
	`passphrase` text,
	`created_at` integer NOT NULL
);
