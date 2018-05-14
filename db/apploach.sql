-- create database apploach;

create table `nobj` (
  `app_id` bigint unsigned not null,
  `nobj_id` bigint unsigned not null,
  `nobj_key` varbinary(4095) not null,
  `nobj_key_sha` binary(40) not null,
  `timestamp` double not null,
  primary key (`nobj_id`),
  key (`app_id`, `nobj_key_sha`),
  key (`app_id`, `timestamp`),
  key (`timestamp`)
) default charset=binary engine=innodb;

create table `comment` (
  `app_id` bigint unsigned not null,
  `thread_nobj_id` bigint unsigned not null,
  `comment_id` bigint unsigned not null,
  `author_nobj_id` bigint unsigned not null,
  `data` mediumblob not null,
  `internal_data` mediumblob not null,
  `author_status` tinyint unsigned not null,
  `owner_status` tinyint unsigned not null,
  `admin_status` tinyint unsigned not null,
  `timestamp` double not null,
  primary key (`comment_id`),
  key (`app_id`, `thread_nobj_id`, `timestamp`),
  key (`app_id`, `author_nobj_id`, `timestamp`),
  key (`app_id`, `timestamp`),
  key (`timestamp`)
) default charset=binary engine=innodb;

create table `star` (
  `app_id` bigint unsigned not null,
  `starred_nobj_id` bigint unsigned not null,
  `starred_author_nobj_id` bigint unsigned not null,
  `author_nobj_id` bigint unsigned not null,
  `count` int unsigned not null,
  `item_nobj_id` bigint unsigned not null,
  `created` double not null,
  `updated` double not null,
  primary key (`app_id`, `starred_nobj_id`, `author_nobj_id`, `item_nobj_id`),
  key (`app_id`, `starred_nobj_id`, `created`),
  key (`app_id`, `author_nobj_id`, `created`),
  key (`app_id`, `starred_author_nobj_id`, `created`),
  key (`app_id`, `item_nobj_id`, `created`),
  key (`created`),
  key (`updated`)
) default charset=binary engine=innodb;
