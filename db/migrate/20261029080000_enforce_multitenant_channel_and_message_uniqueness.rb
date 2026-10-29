# frozen_string_literal: true

class EnforceMultitenantChannelAndMessageUniqueness < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    # 1. Deduplicate any stray messages sharing (inbox_id, source_id) keeping the earliest id
    execute <<~SQL.squish
      DELETE FROM messages m1
      USING messages m2
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

    # 2. Enforce global uniqueness on channel_facebook_pages.page_id across all SaaS tenants
    execute <<~SQL.squish
      DELETE FROM channel_facebook_pages f1
      USING channel_facebook_pages f2
      WHERE f1.page_id = f2.page_id
        AND f1.id > f2.id;
    SQL

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

    # 3. Enforce global uniqueness on channel_facebook_pages.instagram_id when present
    unless index_exists?(:channel_facebook_pages, :instagram_id, name: 'index_channel_facebook_pages_on_instagram_id_unique')
      add_index :channel_facebook_pages,
                :instagram_id,
                unique: true,
                where: "instagram_id IS NOT NULL AND instagram_id <> ''",
                algorithm: :concurrently,
                name: 'index_channel_facebook_pages_on_instagram_id_unique'
    end
  end

  def down
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
