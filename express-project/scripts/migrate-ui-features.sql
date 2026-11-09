-- ============================================================
-- 小石榴 UI 功能扩展 - 增量迁移脚本
-- 依据 UI小石榴.sketch 设计稿，补齐后端缺失功能的数据表
-- 适用：已部署的 xiaoshiliu 数据库（在现有 init-database.sql 基础上执行）
-- 幂等：全部使用 IF NOT EXISTS / INSERT IGNORE，可安全重复执行
-- ============================================================
USE `xiaoshiliu`;

-- 1. 音乐库（供发布页"添加音乐"、首页"原声"标签使用）
CREATE TABLE IF NOT EXISTS `musics` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '音乐ID',
  `title` varchar(200) NOT NULL COMMENT '歌曲名',
  `author` varchar(100) DEFAULT NULL COMMENT '作者/歌手',
  `audio_url` varchar(500) NOT NULL COMMENT '音频URL',
  `cover_url` varchar(500) DEFAULT NULL COMMENT '封面URL',
  `duration` int(11) DEFAULT 0 COMMENT '时长（秒）',
  `use_count` int(11) DEFAULT 0 COMMENT '被使用次数',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_use_count` (`use_count`),
  KEY `idx_title` (`title`(191))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='音乐库表';

-- 2. 投票（全屏播放器投票组件）
CREATE TABLE IF NOT EXISTS `polls` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '投票ID',
  `post_id` bigint(20) NOT NULL COMMENT '所属笔记ID',
  `question` varchar(255) NOT NULL COMMENT '投票问题',
  `ends_at` timestamp NULL DEFAULT NULL COMMENT '结束时间（NULL表示不限时）',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_post` (`post_id`),
  CONSTRAINT `polls_ibfk_1` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='投票表';

CREATE TABLE IF NOT EXISTS `poll_options` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '选项ID',
  `poll_id` bigint(20) NOT NULL COMMENT '投票ID',
  `content` varchar(255) NOT NULL COMMENT '选项内容',
  `vote_count` int(11) DEFAULT 0 COMMENT '票数',
  `sort_order` int(11) DEFAULT 0 COMMENT '排序',
  PRIMARY KEY (`id`),
  KEY `idx_poll_id` (`poll_id`),
  CONSTRAINT `poll_options_ibfk_1` FOREIGN KEY (`poll_id`) REFERENCES `polls` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='投票选项表';

CREATE TABLE IF NOT EXISTS `poll_votes` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '投票记录ID',
  `poll_id` bigint(20) NOT NULL COMMENT '投票ID',
  `option_id` bigint(20) NOT NULL COMMENT '选项ID',
  `user_id` bigint(20) NOT NULL COMMENT '投票用户ID',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '投票时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_poll_user` (`poll_id`, `user_id`),
  KEY `idx_option_id` (`option_id`),
  CONSTRAINT `poll_votes_ibfk_1` FOREIGN KEY (`poll_id`) REFERENCES `polls` (`id`) ON DELETE CASCADE,
  CONSTRAINT `poll_votes_ibfk_2` FOREIGN KEY (`option_id`) REFERENCES `poll_options` (`id`) ON DELETE CASCADE,
  CONSTRAINT `poll_votes_ibfk_3` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='投票记录表';

-- 3. 弹幕（视频播放器）
CREATE TABLE IF NOT EXISTS `danmaku` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '弹幕ID',
  `post_id` bigint(20) NOT NULL COMMENT '笔记ID',
  `user_id` bigint(20) NOT NULL COMMENT '发送用户ID',
  `content` varchar(255) NOT NULL COMMENT '弹幕内容',
  `offset_sec` int(11) DEFAULT 0 COMMENT '出现时间点（视频秒数）',
  `color` varchar(9) DEFAULT '#FFFFFF' COMMENT '颜色',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_post_id` (`post_id`),
  KEY `idx_post_offset` (`post_id`, `offset_sec`),
  CONSTRAINT `danmaku_ibfk_1` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `danmaku_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='弹幕表';

-- 4. 搜索记录（热搜榜 / 猜你想搜）
CREATE TABLE IF NOT EXISTS `search_logs` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '记录ID',
  `user_id` bigint(20) DEFAULT NULL COMMENT '搜索用户ID（可空）',
  `keyword` varchar(100) NOT NULL COMMENT '搜索关键词',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '搜索时间',
  PRIMARY KEY (`id`),
  KEY `idx_keyword` (`keyword`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='搜索记录表';

-- 5. 金币钱包
CREATE TABLE IF NOT EXISTS `user_wallets` (
  `user_id` bigint(20) NOT NULL COMMENT '用户ID',
  `coin_balance` int(11) NOT NULL DEFAULT 0 COMMENT '金币余额',
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`user_id`),
  CONSTRAINT `user_wallets_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户钱包表';

CREATE TABLE IF NOT EXISTS `coin_transactions` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '流水ID',
  `user_id` bigint(20) NOT NULL COMMENT '用户ID',
  `amount` int(11) NOT NULL COMMENT '变动数量（正为收入，负为支出）',
  `type` tinyint(4) NOT NULL COMMENT '类型：1-收入，2-支出',
  `scene` varchar(50) NOT NULL COMMENT '场景：register/post/like/follow/withdraw/vip/order',
  `balance_after` int(11) NOT NULL COMMENT '变动后余额',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_created_at` (`created_at`),
  CONSTRAINT `coin_transactions_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='金币流水表';

-- 6. VIP 会员
CREATE TABLE IF NOT EXISTS `vip_plans` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '套餐ID',
  `name` varchar(50) NOT NULL COMMENT '套餐名称',
  `level` tinyint(4) NOT NULL DEFAULT 1 COMMENT '会员等级',
  `price_coin` int(11) NOT NULL COMMENT '所需金币',
  `duration_days` int(11) NOT NULL COMMENT '有效天数',
  `perks_json` json DEFAULT NULL COMMENT '权益说明',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='VIP套餐表';

CREATE TABLE IF NOT EXISTS `user_vip` (
  `user_id` bigint(20) NOT NULL COMMENT '用户ID',
  `plan_id` bigint(20) DEFAULT NULL COMMENT '最近开通的套餐ID',
  `level` tinyint(4) NOT NULL DEFAULT 0 COMMENT '当前等级：0-非会员',
  `start_at` timestamp NULL DEFAULT NULL COMMENT '开始时间',
  `expire_at` timestamp NULL DEFAULT NULL COMMENT '到期时间',
  PRIMARY KEY (`user_id`),
  CONSTRAINT `user_vip_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户会员表';

-- 6.1 金币获取方式
CREATE TABLE IF NOT EXISTS `coin_earn_rules` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `code` varchar(50) NOT NULL COMMENT '规则编码：comment/danmaku/watch_ad/watch_video/publish_note/publish_video',
  `name` varchar(50) NOT NULL COMMENT '获取方式名称',
  `description` varchar(255) DEFAULT NULL COMMENT '说明文案',
  `reward_coin` int(11) NOT NULL DEFAULT 0 COMMENT '每次奖励金币数',
  `daily_limit` int(11) NOT NULL DEFAULT 0 COMMENT '每日次数上限，0-不限',
  `auto_reward` tinyint(1) NOT NULL DEFAULT 0 COMMENT '1-完成行为自动发放，0-用户手动领取',
  `enabled` tinyint(1) NOT NULL DEFAULT 1 COMMENT '1-启用，0-停用',
  `sort_order` int(11) NOT NULL DEFAULT 0 COMMENT '排序值',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='金币获取方式表';

INSERT IGNORE INTO `coin_earn_rules` (`code`, `name`, `description`, `reward_coin`, `daily_limit`, `auto_reward`, `enabled`, `sort_order`) VALUES
('watch_ad', '看广告', '观看一段激励广告即可领取金币', 10, 5, 0, 1, 1),
('watch_video', '看视频', '观看视频达到时长即可领取金币', 5, 10, 0, 1, 2),
('publish_video', '发视频', '发布一条视频笔记，审核通过后自动发放', 50, 3, 1, 1, 3),
('publish_note', '发表内容', '发布图文笔记，审核通过后自动发放', 30, 3, 1, 1, 4),
('comment', '发表评论', '发表一条评论自动发放', 5, 10, 1, 1, 5),
('danmaku', '发弹幕', '发送一条弹幕自动发放', 2, 20, 1, 1, 6);

-- 7. 商品与订单
CREATE TABLE IF NOT EXISTS `products` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '商品ID',
  `name` varchar(200) NOT NULL COMMENT '商品名称',
  `cover_url` varchar(500) DEFAULT NULL COMMENT '商品图',
  `price_coin` int(11) NOT NULL COMMENT '价格（金币）',
  `stock` int(11) NOT NULL DEFAULT 0 COMMENT '库存',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品表';

CREATE TABLE IF NOT EXISTS `orders` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '订单ID',
  `user_id` bigint(20) NOT NULL COMMENT '下单用户ID',
  `product_id` bigint(20) NOT NULL COMMENT '商品ID',
  `quantity` int(11) NOT NULL DEFAULT 1 COMMENT '数量',
  `total_coin` int(11) NOT NULL COMMENT '总花费金币',
  `status` tinyint(4) NOT NULL DEFAULT 0 COMMENT '状态：0-待发货，1-已发货，2-已完成',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '下单时间',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  CONSTRAINT `orders_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `orders_ibfk_2` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单表';

-- ============================================================
-- 现有表扩展列（MySQL 不支持 ADD COLUMN IF NOT EXISTS，用存储过程判断）
-- ============================================================
DROP PROCEDURE IF EXISTS `add_column_if_not_exists`;
CREATE PROCEDURE `add_column_if_not_exists`(IN tbl VARCHAR(64), IN col VARCHAR(64), IN definition VARCHAR(255))
BEGIN
  IF NOT EXISTS(SELECT * FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = tbl AND COLUMN_NAME = col) THEN
    SET @ddl = CONCAT('ALTER TABLE `', tbl, '` ADD COLUMN `', col, '` ', definition);
    PREPARE stmt FROM @ddl;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END IF;
END;

CALL add_column_if_not_exists('posts', 'music_id', 'bigint(20) DEFAULT NULL COMMENT ''关联音乐ID''');
CALL add_column_if_not_exists('users', 'is_vip', 'tinyint(1) DEFAULT 0 COMMENT ''是否VIP：0-否，1-是''');

DROP PROCEDURE IF EXISTS `add_column_if_not_exists`;

-- posts.music_id 外键（若不存在则添加）
DROP PROCEDURE IF EXISTS `add_fk_if_not_exists`;
CREATE PROCEDURE `add_fk_if_not_exists`(IN tbl VARCHAR(64), IN fk VARCHAR(64), IN ddl VARCHAR(500))
BEGIN
  IF NOT EXISTS(SELECT * FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = tbl AND CONSTRAINT_NAME = fk) THEN
    SET @s = CONCAT('ALTER TABLE `', tbl, '` ADD CONSTRAINT `', fk, '` ', ddl);
    PREPARE stmt FROM @s;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END IF;
END;

CALL add_fk_if_not_exists('posts', 'fk_posts_music', 'FOREIGN KEY (`music_id`) REFERENCES `musics` (`id`) ON DELETE SET NULL');
DROP PROCEDURE IF EXISTS `add_fk_if_not_exists`;

-- ============================================================
-- 广告位管理
-- ============================================================
CREATE TABLE IF NOT EXISTS `ads` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `title` varchar(100) NOT NULL COMMENT '广告标题',
  `image_url` varchar(500) NOT NULL COMMENT '广告图片地址',
  `link_url` varchar(500) DEFAULT NULL COMMENT '点击跳转链接',
  `position` varchar(50) NOT NULL DEFAULT 'home_banner' COMMENT '广告位标识',
  `status` tinyint(1) NOT NULL DEFAULT 1 COMMENT '1-上线，0-下线',
  `sort_order` int(11) NOT NULL DEFAULT 0 COMMENT '排序值，越小越靠前',
  `start_at` datetime DEFAULT NULL COMMENT '投放开始时间，空表示立即生效',
  `end_at` datetime DEFAULT NULL COMMENT '投放结束时间，空表示长期有效',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_position_status` (`position`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='广告位表';

INSERT IGNORE INTO `ads` (`id`, `title`, `image_url`, `link_url`, `position`, `status`, `sort_order`) VALUES
(1, '欢迎来到小石榴', 'https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=campus%20life%20banner%20students%20colorful%20autumn%20campus%20cheerful&image_size=landscape_16_9', '/explore', 'home_banner', 1, 0);

-- ============================================================
-- 邮箱验证配置（后台可管理）
-- ============================================================
CREATE TABLE IF NOT EXISTS `email_settings` (
  `id` tinyint(3) unsigned NOT NULL DEFAULT 1 COMMENT '固定为1，单行配置',
  `enabled` tinyint(1) NOT NULL DEFAULT 0 COMMENT '是否启用邮箱验证',
  `host` varchar(255) NOT NULL DEFAULT 'smtp.qq.com' COMMENT 'SMTP服务器',
  `port` int(11) NOT NULL DEFAULT 465 COMMENT 'SMTP端口',
  `secure` tinyint(1) NOT NULL DEFAULT 1 COMMENT '1-SSL，0-普通',
  `user` varchar(255) NOT NULL DEFAULT '' COMMENT 'SMTP账号',
  `password` varchar(255) NOT NULL DEFAULT '' COMMENT 'SMTP密码/授权码',
  `from_email` varchar(255) NOT NULL DEFAULT '' COMMENT '发件人邮箱，空则使用SMTP账号',
  `from_name` varchar(100) NOT NULL DEFAULT '小石榴校园图文社区' COMMENT '发件人名称',
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='邮箱验证配置表';

INSERT IGNORE INTO `email_settings` (`id`, `enabled`, `host`, `port`, `secure`, `user`, `password`, `from_email`, `from_name`)
VALUES (1, 0, 'smtp.qq.com', 465, 1, '', '', '', '小石榴校园图文社区');

-- ============================================================
-- 种子数据（VIP套餐、示例商品、示例音乐）
-- ============================================================
INSERT IGNORE INTO `vip_plans` (`id`, `name`, `level`, `price_coin`, `duration_days`, `perks_json`) VALUES
(1, '超级会员·月卡', 1, 1000, 30, JSON_ARRAY('高清画质', '去广告', '抢先看')),
(2, '超级会员·季卡', 2, 2700, 90, JSON_ARRAY('高清画质', '去广告', '抢先看', '专属标识')),
(3, '超级会员·年卡', 3, 9800, 365, JSON_ARRAY('高清画质', '去广告', '抢先看', '专属标识', '客服优先')),
(4, '超级会员·钻石月卡', 4, 1800, 30, JSON_ARRAY('高清画质', '去广告', '抢先看', '专属标识', '蓝光1080P')),
(5, '超级会员·钻石季卡', 5, 4800, 90, JSON_ARRAY('高清画质', '去广告', '抢先看', '专属标识', '蓝光1080P', '评论置顶')),
(6, '超级会员·至尊年卡', 6, 16800, 365, JSON_ARRAY('高清画质', '去广告', '抢先看', '专属标识', '蓝光1080P', '评论置顶', '直播特权', '客服优先')),
(7, '超级会员·皇冠年卡', 7, 28800, 365, JSON_ARRAY('高清画质', '去广告', '抢先看', '专属标识', '蓝光1080P', '评论置顶', '直播特权', '客服优先', '专属装扮', '优先体验'));

INSERT IGNORE INTO `products` (`id`, `name`, `price_coin`, `stock`) VALUES
(1, '小石榴官方周边 T恤', 5000, 100),
(2, '石榴籽保温杯', 8000, 50),
(3, '创作者徽章套装', 3000, 200);

SELECT 'UI功能扩展迁移完成！' AS message;
