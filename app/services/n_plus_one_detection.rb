# frozen_string_literal: true

# Prosopite は development/test グループの gem。本番環境や、gem 追加前に起動した
# 常駐ワーカープロセスでは定数が存在せず、直接参照すると NameError になる。
# N+1 検知の一時停止は「あれば使う」補助機能なので、未ロード時は素通しさせる。
module NPlusOneDetection
  module_function

  def pause(&)
    if defined?(Prosopite)
      Prosopite.pause(&)
    else
      yield
    end
  end
end
