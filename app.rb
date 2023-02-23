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
 
    sought_id = params[:media_id].to_i

    sought_media = db.execute("SELECT * FROM Media WHERE Media.id = ?", sought_id)

    if sought_media.empty?
       return slim(:"error", locals:{document_title: "404", error_message: "The media specified is not found."})
    end

    genres = db.execute("SELECT Genre.name FROM Genre INNER JOIN Media_genre_relation ON Genre.id = Media_genre_relation.genre_id WHERE Media_genre_relation.media_id = ?;", sought_id)
    authors = db.execute("SELECT Author.name FROM Author INNER JOIN Media_author_relation ON Author.id = Media_author_relation.author_id WHERE Media_author_relation.media_id = ?", sought_id)
   
    slim(:"media", locals:{document_title: sought_media[0]["name"], media: sought_media[0], genres: genres, authors: authors })
end

get("/admin") do

end