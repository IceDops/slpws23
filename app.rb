require "sinatra"
require "slim"
require "sqlite3"
require "bcrypt"
require "sinatra/reloader"
require_relative "./model.rb"

enable :sessions

get('/') do 
    slim(:"index", locals:{document_title: "Home"})
end


get("/signup") do

end

get("/search") do

end

get("/users/:user_id") do

end

get("/author/:author_id") do
end

get("/media/:media_id") do
    slim(:"media", locals:{document_title: "Home"})
    
    #db = database("./db/main.db")
    #print(db.execute("SELECT * FROM Media"))
    tester()

end

get("/admin") do

end