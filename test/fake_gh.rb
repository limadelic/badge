class FakeGh
  attr_reader :calls, :patched

  def initialize(body: '', pulls: '[]')
    @body = body
    @pulls = pulls
    @calls = []
    @patched = nil
  end

  def call(*args)
    @calls << args
    return "#{@pulls}\n" if args.first.start_with?('repos/limadelic/badge/pulls?')
    return "#{@body}\n" if args.include?('--jq')

    @patched = File.read(args.last.delete_prefix('body=@'))
    ''
  end
end
