# -*- coding: utf-8 -*-

Plugin.create :block do
  
  command(:block,
          name: 'ブロックする',
          condition: Plugin::Command::CanReplyAll,
          visible: true,
          icon: nil,
          role: :timeline) do |opt|
            user = opt.messages.first.user
            if ::Gtk::Dialog.confirm("@#{user[:idname]}をブロックしますよ、本当にいいんですか？")
              if ::Gtk::Dialog.confirm("取り返しが付かないですがよろしいですね？")
                (Service.primary.twitter/'blocks/create').json(:screen_name => user[:idname])
              end
            end
          end
end
