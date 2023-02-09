require "sinatra"
require "slim"
require "sqlite3"
require "bcrypt"
require "sinatra/reloader"
require_relative "./model.rb"

enable :sessions

db = database("./db/main.db")

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
 

    medias = db.execute("SELECT * FROM Media")

    sought_media = nil
    sought_id = params[:media_id].to_i

    medias.each do | media |
        if media["id"] == sought_id 
            sought_media = media 
        end
    end

    if sought_media == nil 
       return slim(:"error", locals:{document_title: "404", error_message: "The media specified is not found."})
    end

    slim(:"media", locals:{document_title: sought_media["name"], media: sought_media})
   end

get("/admin") do

end