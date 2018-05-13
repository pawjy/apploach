-- create database apploach;

create table `target` (
  `app_id` bigint unsigned not null,
  `target_id` bigint unsigned not null,
  `target_key` varbinary(4095) not null,
  `target_key_sha` binary(40) not null,
  `timestamp` double not null,
  primary key (`target_id`),
  key (`app_id`, `target_key_sha`),
  key (`app_id`, `timestamp`),
  key (`timestamp`)
) default charset=binary engine=innodb;

create table `comment` (
  `app_id` bigint unsigned not null,
  `target_id` bigint unsigned not null,
  `comment_id` bigint unsigned not null,
  `author_account_id` bigint unsigned not null,
  `data` mediumblob not null,
  `internal_data` mediumblob not null,
  `author_status` tinyint unsigned not null,
  `target_owner_status` tinyint unsigned not null,
  `admin_status` tinyint unsigned not null,
  `timestamp` double not null,
  primary key (`comment_id`),
  key (`app_id`, `target_id`, `timestamp`),
  key (`app_id`, `author_account_id`, `timestamp`),
  key (`app_id`, `timestamp`),
  key (`timestamp`)
) default charset=binary engine=innodb;

create table `star` (
  `app_id` bigint unsigned not null,
  `target_id` bigint unsigned not null,
  `target_author_account_id` bigint unsigned not null,
  `author_account_id` bigint unsigned not null,
  `count` int unsigned not null,
  `item_target_id` bigint unsigned not null,
  `created` double not null,
  `updated` double not null,
  primary key (`app_id`, `target_id`, `author_account_id`, `item_target_id`),
  key (`app_id`, `target_id`, `created`),
  key (`app_id`, `author_account_id`, `created`),
  key (`app_id`, `target_author_account_id`, `created`),
  key (`app_id`, `item_target_id`, `created`),
  key (`created`),
  key (`updated`)
) default charset=binary engine=innodb;
