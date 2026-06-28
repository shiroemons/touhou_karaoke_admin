module Admin
  module Operations
    class BaseOperation
      private

      def message(text)
        OperationRunner::Result.new(message: text, download_data: nil, download_filename: nil, download_content_type: nil)
      end

      def download(data, filename)
        OperationRunner::Result.new(
          message: "#{filename}を生成しました。",
          download_data: data,
          download_filename: filename,
          download_content_type: 'text/tab-separated-values; charset=utf-8'
        )
      end
    end
  end
end
