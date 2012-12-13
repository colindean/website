# vim: set ts=2 sw=2 et ai ft=ruby:
# encoding: utf-8

module Fosdem

  def henc(text)
    $_html_entities_encoder ||= begin
                                  require 'htmlentities'
                                  HTMLEntities.new
                                end
    if text
      $_html_entities_encoder.encode text
    else
      text
    end
  end

  def stripext(filename)
    d, b, e = split_filename filename
    if e.size > 0
      b[0..-(e.size + 2)]
    else
      b
    end
  end

  def split_filename(filename)
    d = begin
          d = File.dirname filename
          if d.nil? or d == '' or d == '.'
            nil
          else
            d
          end
        end
    b = File.basename filename
    case b
    when %r{^(.+)\.(([^\.]+)\.(gz|bz|bz2|xz))$}
      [ d, $1, $2 ]
    when %r{^(.+)\.([^\.]+)$}
      [ d, $1, $2 ]
    when %r{^(.+)\.$}
      [ d, $1, '' ]
    when %r{^([^\.]+)$}
      [ d, $1, '' ]
    else
      [ d, filename, '' ]
    end
  end

  def sanitize_filename(filename)
    d, b, e = split_filename(filename)
    require 'active_support/inflector/transliterate'
    require 'active_support/inflector/methods'
    b = ActiveSupport::Inflector
    .transliterate(b)
    .gsub(%r{/+}, '')
    .gsub(%r{\s+}, '_')
    .gsub(/[\s\-\+]+/, '_')
    .gsub(/[\._]+/, '_')
    .gsub(/["']+/, '')
    [ d, "#{b}.#{e}", b, e ]
  end

  def sha_file(filename)
    require 'digest/sha1'
    Digest::SHA1.file(filename).to_s.downcase
  end

  def md5_file(filename)
    require 'digest/md5'
    Digest::MD5.file(filename).to_s.downcase
  end

  def mime_to_extension(mime)
    case mime
    when 'image/png'
      'png'
    when 'image/gif'
      'gif'
    when 'image/jpeg'
      'jpg'
    else
      fail "unsupported image MIME type \"#{mime}\""
    end
  end

  def image_size(filename)
    require 'RMagick'
    image = Magick::Image.from_blob(IO.read(filename)).first
    begin
      [ image.columns, image.rows ]
    ensure
      image.destroy! if image
    end
  end

  def all_exist(*files)
    files.map{|f| File.exists? f}.all?
  end

  def hash_by(ary, key)
    h = {}
    ary.each do |item|
      h[item.fetch(key)] = item
    end
    h
  end

  def iso822(time)
    require 'time'
    time = case time
           when Date
             time
           when Time
             time
           when String
             Time.parse(time)
           else
             fail "unsupported class: #{time.class} #{time.inspect}"
           end
    time.rfc2822
  end

  def excerpt_words(text, limit, more="\u{8230}")
    words = text.split(/\s+/)
    if words.size >= limit
      words[0..(limit-1)].join(" ") + more
    else
      words.join(" ")
    end
  end

  def html_to_text(html)
    require 'nokogiri'
    Nokogiri::HTML(html).text
  end

  def sprite_css(css_rule_to_filename_hash)
    h = {}

    begin
      h =
        begin
          h = {}
          css_rule_to_filename_hash.each do |rule, filename|
            filename = case filename
                       when Nanoc::Item
                         filename[:filename]
                       when String
                         if filename.start_with? '/' and filename.end_with? '/'
                           $item_by_id.fetch(filename)[:filename]
                         else
                           filename
                         end
                       else
                         fail "unsupported #{f.class} #{f.inspect}"
                       end
            h[rule] = Magick::Image.from_blob(IO.read(filename)).first
          end
          h
        end

      y = 0
      h.map do |rule, image|
        line = %Q&#{rule} { width: #{image.columns}px !important; height: #{image.rows}px !important; background-position: 0 #{-y}px !important; }&
        y += image.rows
        line
      end
      .join("\n")
    ensure
      h.each do |rule, img|
        begin
          img.destroy! if img
        rescue
        end
      end
    end

  end

  def sprite_image(filenames, format='PNG', optimize=true)
    require 'RMagick'

    images = []
    begin
      images = filenames
      .map do |f|
        case f
        when Nanoc::Item
          f[:filename]
        when String
          if f.start_with? '/' and f.end_with? '/'
            $item_by_id.fetch(f)[:filename]
          else
            f
          end
        else
          fail "unsupported #{f.class} #{f.inspect}"
        end
      end
      .map do |f|
        Magick::Image.from_blob(IO.read(f)).first
      end

      width  = images.map{|i| i.columns}.max
      height = images.map{|i| i.rows}.inject(0, :+)

      sprite = nil
      begin
        sprite = Magick::Image.new(width, height) do
          self.format = format
          self.background_color = 'transparent'
        end

        y = 0
        images.each do |image|
          sprite.composite!(image, 0, y, Magick::OverCompositeOp)
          y += image.rows
        end

        temp = nil
        tempopt = nil
        begin
          require 'tempfile'
          temp = Tempfile.new("unoptimized-#{@item[:filename]}".gsub(%r{/+}, '_'))
          temp.write(sprite.to_blob)
          temp.flush
          tempopt = Tempfile.new("optimized-#{@item[:filename]}".gsub(%r{/+}, '_'))
          %x{pngcrush -q #{temp.path} #{tempopt.path}} or fail "failed to run pngcrush"
          tempopt.rewind
          content = tempopt.read
          content
        ensure
          if temp
            begin
              temp.close
            ensure
              temp.unlink
            end
          end
          if tempopt
            begin
              tempopt.close
            ensure
              tempopt.unlink
            end
          end
        end

      ensure
        sprite.destroy! if sprite
      end

    ensure
      images.each do |img|
        begin
          img.destroy! if img
        rescue
        end
      end
    end
  end

end #Fosdem

