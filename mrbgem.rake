MRuby::Gem::Specification.new('mruby-compiler2') do |spec|
  spec.license = 'MIT'
  spec.author  = 'HASUMI Hitoshi'
  spec.summary = 'mruby compiler using a universal parser'

  lib_dir = "#{dir}/lib"
  cc.include_paths << "#{dir}/include"

  prism_dir = "#{lib_dir}/prism"
  ruby_dir = "#{lib_dir}/ruby"

  cc.defines.flatten!

  cc.defines << "PRISM_XALLOCATOR"
  if cc.defines.include?("PICORB_VM_MRUBY")
    cc.defines << "MRC_TARGET_MRUBY"
  elsif cc.defines.include?("PICORB_VM_MRUBYC")
    cc.defines << "MRC_TARGET_MRUBYC"
  end

  if cc.defines.include?("PICORB_INT32")
    cc.defines << "MRC_INT64"
  end
  if cc.defines.any? { _1.match? /\A(PICORUBY|MRB)_DEBUG(=|\z)/ }
    cc.defines << "MRC_DEBUG"
    cc.defines << "MRC_DUMP_PRETTY"
  else
    cc.defines << "PRISM_BUILD_MINIMAL"
  end

  prism_templates_dir = "#{lib_dir}/prism/templates"
  cc.include_paths << "#{prism_dir}/include"

  next if %w(clean deep_clean).include?(Rake.application.top_level_tasks.first)

  # Ensure prism submodule is initialized.
  # Note: `directory` task won't fire when the empty dir already exists
  # (git clone creates submodule dirs as empty directories).
  unless File.exist?("#{prism_dir}/include/prism.h")
    FileUtils.cd dir do
      sh "git submodule update --init"
    end
  end

  prism_generated_srcs = %w(node prettyprint serialize token_type diagnostic)
  prism_generated_headers = %w(include/prism/ast.h include/prism/diagnostic.h)

  # Generate templated files if any are missing
  unless (prism_generated_srcs.all? { |n| File.exist?("#{prism_dir}/src/#{n}.c") } &&
          prism_generated_headers.all? { |h| File.exist?("#{prism_dir}/#{h}") })
    FileUtils.cd prism_dir do
      ruby "templates/template.rb"
    end
  end

  prism_generated_srcs.each do |name|
    dst = "#{prism_dir}/src/#{name}.c"
    file dst => ["#{prism_templates_dir}/src/#{name}.c.erb", "#{prism_templates_dir}/template.rb"] do |t|
      FileUtils.cd prism_dir do
        ruby "templates/template.rb"
      end
    end
  end

  Dir.glob("#{prism_dir}/src/**/*.c").map do |src|
    obj = objfile(src.pathmap("#{build_dir}/lib/%n"))
    objs << obj
    file obj => [src] do |f|
      cc.run f.name, f.prerequisites.first
    end
  end

end

