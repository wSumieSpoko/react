require 'sinatra'
require 'sqlite3'
require 'bcrypt'
require 'json'

# Inicjalizacja bazy danych
DB = SQLite3::Database.new 'calendar0.db'
DB.results_as_hash = true


# Konfiguracja sesji
enable :sessions

# Strona główna (formularze rejestracji i logowania)
get '/' do
  erb :index
end

# Strona kalendarza po zalogowaniu
get '/calendar' do
  redirect '/' if session[:user_id].nil?
  erb :timestamp
end

# Obsługa rejestracji użytkownika
post '/register' do
  user = params[:user]
  password = params[:password]

  return "Wszystkie pola są wymagane!" if user.strip.empty? || password.strip.empty?

  hashed_password = BCrypt::Password.create(password)
  DB.execute('INSERT INTO users (user, password) VALUES (?, ?)', [user, hashed_password])

  session[:register_success] = true
  redirect '/'
end

# Obsługa logowania użytkownika
post '/login' do
  user = params[:loginUser]
  password = params[:loginPassword]

  return "Wszystkie pola są wymagane!" if user.strip.empty? || password.strip.empty?

  result = DB.execute('SELECT id, password FROM users WHERE user = ?', [user])

  if result.empty?
    session[:login_error] = true
    return redirect '/'
  end

  stored_password = result.first['password']
  if BCrypt::Password.new(stored_password) == password
    session[:user_id] = result.first['id']
    session[:login_success] = true 
    redirect '/calendar'
  else
    # Błąd logowania
    session[:login_error] = true
    return redirect '/'
  end
end

# Obsługa wylogowania
get '/logout' do
  session.clear 
  session[:logout_success] = true 
  redirect '/' 
end



# Pobieranie zalogowanego użytkownika
get '/current_user' do
  content_type :json
  return { user: nil }.to_json if session[:user_id].nil?

  user_data = DB.execute('SELECT user FROM users WHERE id = ?', [session[:user_id]]).first
  { user: user_data ? user_data['user'] : nil }.to_json
end

# Pobieranie wydarzeń użytkownika
get '/events' do
  content_type :json
  return { error: "Zaloguj się, aby zobaczyć wydarzenia." }.to_json if session[:user_id].nil?

  user_data = DB.execute('SELECT user FROM users WHERE id = ?', [session[:user_id]]).first
  return { error: "Błąd autoryzacji." }.to_json if user_data.nil?

  user_name = user_data['user']
  events = DB.execute('SELECT id, event_date, event_time, description FROM events WHERE user_name = ?', [user_name])
  
  events.to_json
end

# Dodawanie wydarzenia do bazy
post '/add_event' do
  content_type :json
  return { error: "Zaloguj się, aby dodać wydarzenie." }.to_json if session[:user_id].nil?

  data = JSON.parse(request.body.read)
  event_date = data['event_date']
  event_time = data['event_time']
  description = data['description']

  user_data = DB.execute('SELECT user FROM users WHERE id = ?', [session[:user_id]]).first
  return { error: "Błąd autoryzacji." }.to_json if user_data.nil?

  user_name = user_data['user']

  if [event_date, event_time, description].any? { |field| field.strip.empty? }
    return { error: "Wszystkie pola są wymagane!" }.to_json
  end

  DB.execute('INSERT INTO events (user_name, event_date, event_time, description) VALUES (?, ?, ?, ?)',
             [user_name, event_date, event_time, description])

  { message: "Wydarzenie zapisane!" }.to_json
end

# Usuwanie wydarzenia
post '/delete_event' do
  content_type :json
  return { error: "Zaloguj się, aby usunąć wydarzenie." }.to_json if session[:user_id].nil?

  # Odbieranie ID 
  request_payload = JSON.parse(request.body.read)
  event_id = request_payload['id']

  return { error: "Brak ID wydarzenia!" }.to_json if event_id.nil? || event_id.strip.empty?

  user_data = DB.execute('SELECT user FROM users WHERE id = ?', [session[:user_id]]).first
  return { error: "Błąd autoryzacji." }.to_json if user_data.nil?

  user_name = user_data['user']

  # Usunięcie wydarzenia
  DB.execute('DELETE FROM events WHERE id = ? AND user_name = ?', [event_id, user_name])

  { message: "Wydarzenie usunięte!" }.to_json
end
