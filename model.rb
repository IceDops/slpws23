def database(path) 
    db = SQLite3::Database.new('db/main.db')
	db.results_as_hash = true
    return db
end

def tester()
    print("hello world!")
end
