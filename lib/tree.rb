require 'fileutils'

module Tree
  module_function

  def copy(source, dir)
    FileUtils.cp_r(source, dir)
  end
end
