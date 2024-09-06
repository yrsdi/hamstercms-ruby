require 'sinatra'
require 'net/ldap'

# Constants for the default template and directory
DEFAULT_TEMPLATE = 'plain'
DEFAULT_DIRECTORY = 'files'

# LDAP server configuration
LDAP_HOST = 'ldap.example.com'   # Replace with your LDAP server
LDAP_PORT = 389                  # Default port is 389
LDAP_BASE = 'dc=example,dc=com'  # Replace with your LDAP base DN
LDAP_AUTH_USER = 'cn=admin,dc=example,dc=com' # Replace with your LDAP admin user
LDAP_AUTH_PASSWORD = 'admin_password'         # Replace with your LDAP admin password

# LDAP Authentication function
def authenticate(username, password)
  ldap = Net::LDAP.new(
    host: LDAP_HOST,
    port: LDAP_PORT,
    auth: {
      method: :simple,
      username: "uid=#{username},#{LDAP_BASE}",
      password: password
    }
  )

  if ldap.bind
    true
  else
    false
  end
end

# Before filter to protect routes
before do
  protected! unless request.path_info == '/login'
end

# Authentication required method
def protected!
  unless authorized?
    response['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
    halt 401, "Not authorized\n"
  end
end

# Authorization method
def authorized?
  @auth ||=  Rack::Auth::Basic::Request.new(request.env)
  if @auth.provided? && @auth.basic? && @auth.credentials
    authenticate(@auth.credentials[0], @auth.credentials[1])
  else
    false
  end
end

# Define a login route for testing
get '/login' do
  if authorized?
    "Welcome, #{request.env['REMOTE_USER']}!"
  else
    halt 401, "Not authorized\n"
  end
end

# Serve static files (CSS, JS, images) from the templates directory
get '/:template/*' do
  template = params['template']
  file_path = "./templates/#{template}/#{params['splat'].first}"

  if File.exist?(file_path)
    send_file file_path
  else
    halt 404, "File not found: #{file_path}"
  end
end

# Define the route for serving the main content
get '/*' do
  page_param = params['splat'].first # Get the page from the URL
  page = if page_param && !page_param.empty?
           "./#{DEFAULT_DIRECTORY}/#{page_param.gsub(/[^a-zA-Z0-9_\-]/, '')}.txt"
         end

  # If no specific page is requested or the page does not exist
  if page.nil? || !File.exist?(page)
    nav = Dir.glob("#{DEFAULT_DIRECTORY}/*.txt").sort
    page = nav.first # Set the first page alphabetically as the default page
  end

  # Read and process the template
  template_name = File.exist?("#{page}_") ? File.read("#{page}_").strip : DEFAULT_TEMPLATE
  template_file = "./templates/#{template_name}/index.html"
  halt 404, "Template not found (#{template_file})" unless File.exist?(template_file)

  output = File.read(template_file)
  output.gsub!('[[CONTENTS]]', File.read(page)) # Replace CONTENTS placeholder with the page content

  # Generate navigation links
  navigation = ''
  if output.include?('[[NAVIGATION]]')
    nav = Dir.glob("#{DEFAULT_DIRECTORY}/*.txt").sort
    nav.each do |file|
      link = File.basename(file, '.txt')
      navigation += "<a href=\"/#{link == 'index' ? '' : link}\">#{link}</a><br>\n"
    end
    output.gsub!('[[NAVIGATION]]', navigation)
  end

  # Replace included files
  output.gsub!(/\[\[([^\]]+\.txt)\]\]/) do
    included_file = File.join('includes', $1)
    File.exist?(included_file) ? File.read(included_file) : match
  end

  erb output
end