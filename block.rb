# -*- coding: utf-8 -*-

Plugin.create :block do

    UserConfig[:block_update_interval] ||= 15

    @blocked_ids     = []
    @no_retweets_ids = []
    @muted_user_ids  = []
    
    command(:block,
        name: 'ブロックする',
        condition: Plugin::Command::CanReplyAll,
        visible: true,
        icon: nil,
        role: :timeline) do |opt|
        user = opt.messages.first.user
        if ::Gtk::Dialog.confirm("@#{user[:idname]}をブロックしますよ、本当にいいんですか？")
            if ::Gtk::Dialog.confirm("取り返しが付かないですがよろしいですね？")
                (Service.primary.twitter/'blocks/create').json(:screen_name => user[:idname]).next do
                    @blocked_ids << user[:id]
                end
            end
        end
    end

    filter_show_filter do |msgs|
        msgs = msgs.select do |m|
            if UserConfig[:block_filter_blocked] then !@blocked_ids.include?(m.user[:id]) else true end
        end.select do |m|
            if UserConfig[:block_filter_muted_user] then !@muted_user_ids.include?(m.user[:id]) else true end
        end
        [msgs]
    end

    filter_show_filter do |msgs|
        msgs = msgs.select do |m|
            if m.retweet? 
                if UserConfig[:block_filter_no_retweets] then !@no_retweets_ids.include?(m.user[:id]) else true end
            else
                true
            end
        end
        [msgs]
    end

    def fetch_cursor_api(service, endpoint, cursor, &block)
        (service.twitter/endpoint).json(:cursor => cursor).next do |json|
            block.call(json) if block_given?
            fetch_cursor_api(service, endpoint, cursor) unless json[:next_cursor] == 0
        end
    end

    def update_filter_ids
        Service.each do |service|
            fetch_cursor_api(service, 'blocks/ids', -1) do |json|
                @blocked_ids.concat(json[:ids]).uniq!
            end
            fetch_cursor_api(service, 'mutes/users/ids', -1) do |json|
                @muted_user_ids.concat(json[:ids]).uniq!
            end
            (service.twitter/'friendships/no_retweets/ids').json({}).next do |json|
                @no_retweets_ids.concat(json).uniq!
            end
        end

        Reserver.new(UserConfig[:block_update_interval] * 60) do
            update_filter_ids()
        end
    end

    settings "ブロックとフィルタリング" do
        adjustment "ブロック・RT非表示・ミュートユーザの取得間隔(分)", :block_update_interval, 1, 60
        boolean "ブロック済みユーザをフィルタ", :block_filter_blocked
        boolean "ミュート済みユーザをフィルタ", :block_filter_muted_user
        boolean "公式WebのRT非表示を反映", :block_filter_no_retweets
    end

    update_filter_ids()
end
