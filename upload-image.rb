# encoding: utf-8
$:.push(File.dirname($0))
require 'pashua'
include Pashua


# writes text to clipboard, using a pipe to avoid shell mangling
# rewritten using osascript for better UTF8 support (from http://www.coderaptors.com/?action=browse&diff=1&id=Random_tips_for_Mac_OS_X)
def pbcopy(text)
  `osascript -e 'set the clipboard to "#{text}"'`
  #IO.popen("osascript -e 'set the clipboard to do shell script \"cat\"'","w+") {|pipe| pipe << text}
end

# gets text from clipboard
def pbpaste
  a = IO.popen("osascript -e 'the clipboard as unicode text' | tr '\r' '\n'", 'r+').read
  a.strip.force_encoding("UTF-8")
end

class File
  class << self

    # adds File.write - analogous to File.read, writes text to filename
    def write(filename, text)
      File.open(filename,"w") {|f| f << text}
    end

    # adds File.append - analogous to File.read, writes text to filename
    def append(filename, text)
      File.open(filename,"a") {|f| f << text + "\n"}
    end

    # find the last file added in directory
    def last_added(path)
      path += "*" unless path.index("*")
      Dir.glob(path, File::FNM_CASEFOLD).select {|f| test ?f, f}.sort_by {|f|  File.mtime f}.pop
    end

    # find the last file added in directory
    def last_added_dir(path)
      path += "*" unless path.index("*")
      Dir.glob(path + "/*/", File::FNM_CASEFOLD).sort_by {|f| File.mtime f}.pop
    end


    def replace(path, before, after, newpath = "")
      a = File.read(path)
      a.gsub!(before, after)
      newpath = path if newpath == ""
      File.write(newpath, a)
    end
  end
end


# displays and error message and exits (could optionally log, not implemented right now)
# mainly to enable one-liners instead of if...end
def fail(message)
  growl "Failure!", message
  exit
end

def growl(title,text='',url='')
  if text == ''
    text = title
    title = ''
  end

  `growlnotify -t "#{title}" -m "#{text}"`

  # growlapp=Appscript.app('Growl')
  # growlapp.register({:as_application=>'Linkify', :all_notifications=>['Note'], :default_notifications=>['Note']})
  # growlapp.notify({:with_name=>'Note',:title=>title,:description=>text,:application_name=>'Linkify', :callback_URL=>url})
end

# ----------------------------------------------------------------------------------


def get_pic_dims(filename)
  height = Integer(%x{sips --getProperty pixelHeight "#{filename}" 2>&1}.split(":")[1])
  width = Integer(%x{sips --getProperty pixelWidth "#{filename}" 2>&1}.split(":")[1])

  return  [width, height] # empty array if sips fails
end



curfile =  File.last_added("/Users/Stian/Desktop/Screen*.png") # this might be different between different OSX versions
fail "No screenshots available" if curfile == nil

p curfile
width, height = get_pic_dims(curfile)
fail "Can't get picture dimensions" unless width && height

# Pashua layout
config = "
*.title = image-uploader
fname.type = textfield
fname.label = Image file name
fname.name = filename
fname.tooltip = Choose from the list or enter another name

size.label = Current image dimensions width: #{width}, height: #{height}, resize?
size.type = radiobutton
size.option = 100%
size.option = 50%
size.option = 320 px width
size.option = 640 px width
size.option = 800 px width
size.default = 100%

img.type = image
img.maxwidth = 500
img.maxheight = 500
img.path = #{curfile}

cancel.type = cancelbutton
cancel.label = Cancel
cancel.tooltip = Closes this window without taking action"

pash = pashua_run config
if pash['cancel'] == 1
  pbcopy("")
  exit
end
  

newfname = pash['fname'].strip + ".png"
fail "You didn't supply a filename" unless newfname.size > 0

# check if file exiss
# already = `ssh reganmian.net 'ls "/var/www/images/#{newfname}"'`
# fail "That image already exists" unless already == ""

tmppath = "/tmp/#{newfname}.png"
`mv '#{curfile}' '#{tmppath}'`

unless pash["size"] == "100%"

  newsize = case pash["size"]
  when "50%" then width/2
  when "320 px width" then 320
  when "640 px width" then 640
  when "800 px width" then 800
  end

  `sips --resampleWidth #{newsize} "#{tmppath}"`
end   

`scp '#{tmppath}' 'stian@reganmian.net:/var/www/images/#{newfname}'`

pbcopy("![](http://reganmian.net/images/#{newfname.gsub(" ", "%20")})")