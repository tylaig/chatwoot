# frozen_string_literal: true

class EnforceMultitenantChannelAndMessageUniqueness < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    # 1. Safely clear duplicate source_id on newer messages without deleting any message history
    execute <<~SQL.squish
      UPDATE messages m1
      SET source_id = NULL
      FROM messages m2
      WHERE m1.inbox_id = m2.inbox_id
        AND m1.source_id = m2.source_id
        AND m1.source_id IS NOT NULL
        AND m1.source_id <> ''
        AND m1.id > m2.id;
    SQL

    unless index_exists?(:messages, [:inbox_id, :source_id], name: 'index_messages_on_inbox_id_and_source_id_unique')
      add_index :messages,
                [:inbox_id, :source_id],
                unique: true,
                where: "source_id IS NOT NULL AND source_id <> ''",
                algorithm: :concurrently,
                name: 'index_messages_on_inbox_id_and_source_id_unique'
    end

    # 2. Enforce uniqueness on channel_facebook_pages.page_id when no duplicates exist
    dup_pages = select_value(<<~SQL.squish).to_i
      SELECT COUNT(*) FROM (
        SELECT page_id FROM channel_facebook_pages GROUP BY page_id HAVING COUNT(*) > 1
      ) t
    SQL

    if dup_pages.zero?
      if index_exists?(:channel_facebook_pages, :page_id, name: 'index_channel_facebook_pages_on_page_id')
        remove_index :channel_facebook_pages, name: 'index_channel_facebook_pages_on_page_id', algorithm: :concurrently
      end

      unless index_exists?(:channel_facebook_pages, :page_id, name: 'index_channel_facebook_pages_on_page_id_unique')
        add_index :channel_facebook_pages,
                  :page_id,
                  unique: true,
                  algorithm: :concurrently,
                  name: 'index_channel_facebook_pages_on_page_id_unique'
      end
    end

    # 3. Enforce uniqueness on channel_facebook_pages.instagram_id when present and no duplicates exist
    dup_ig = select_value(<<~SQL.squish).to_i
      SELECT COUNT(*) FROM (
        SELECT instagram_id FROM channel_facebook_pages
        WHERE instagram_id IS NOT NULL AND instagram_id <> ''
        GROUP BY instagram_id HAVING COUNT(*) > 1
      ) t
    SQL

    if dup_ig.zero? && !index_exists?(:channel_facebook_pages, :instagram_id, name: 'index_channel_facebook_pages_on_instagram_id_unique')
      add_index :channel_facebook_pages,
                :instagram_id,
                unique: true,
                where: "instagram_id IS NOT NULL AND instagram_id <> ''",
                algorithm: :concurrently,
                name: 'index_channel_facebook_pages_on_instagram_id_unique'
    end

    # 4. Enforce global uniqueness on channel_whatsapp phone_number_id for whatsapp_cloud
    execute <<~SQL.squish
      CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS index_channel_whatsapp_on_cloud_phone_number_id_unique
      ON channel_whatsapp ((provider_config->>'phone_number_id'))
      WHERE provider = 'whatsapp_cloud'
        AND (provider_config->>'phone_number_id') IS NOT NULL
        AND (provider_config->>'phone_number_id') <> '';
    SQL
  end

  def down
    execute <<~SQL.squish
      DROP INDEX CONCURRENTLY IF EXISTS index_channel_whatsapp_on_cloud_phone_number_id_unique;
    SQL

    if index_exists?(:channel_facebook_pages, :instagram_id, name: 'index_channel_facebook_pages_on_instagram_id_unique')
      remove_index :channel_facebook_pages, name: 'index_channel_facebook_pages_on_instagram_id_unique', algorithm: :concurrently
    end

    if index_exists?(:channel_facebook_pages, :page_id, name: 'index_channel_facebook_pages_on_page_id_unique')
      remove_index :channel_facebook_pages, name: 'index_channel_facebook_pages_on_page_id_unique', algorithm: :concurrently
    end

    unless index_exists?(:channel_facebook_pages, :page_id, name: 'index_channel_facebook_pages_on_page_id')
      add_index :channel_facebook_pages, :page_id, algorithm: :concurrently, name: 'index_channel_facebook_pages_on_page_id'
    end

    if index_exists?(:messages, [:inbox_id, :source_id], name: 'index_messages_on_inbox_id_and_source_id_unique')
      remove_index :messages, name: 'index_messages_on_inbox_id_and_source_id_unique', algorithm: :concurrently
    end
  end
end
