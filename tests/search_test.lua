
-- Adjust the package.path to include the parent directory
package.path = package.path .. ";../?.lua"
local DocumentSearch = require("processes.search")

function dump_table(t, indent)
    indent = indent or 0
    local spaces = string.rep("  ", indent)

    if type(t) ~= "table" then
        if type(t) == "string" then
            return '"' .. t .. '"'
        else
            return tostring(t)
        end
    end

    local result = "{\n"
    for k, v in pairs(t) do
        result = result .. spaces .. "  [" .. tostring(k) .. "] = " .. dump_table(v, indent + 1) .. ",\n"
    end
    result = result .. spaces .. "}"
    return result
end

function print_table(t)
    print(dump_table(t))
end

-- Your test code here
-- Example usage with metadata and filtering
local function example_usage()
    local search = DocumentSearch.new({
        fuzzy_threshold = 0.2,  -- Lower threshold for more fuzzy matches
        fuzzy_weight = 0.3,     -- 30% fuzzy, 70% TF-IDF
        tfidf_weight = 0.7,
        enable_fuzzy = true
    })

    -- Sample book metadata (similar to Arweave transaction tags)
    local sample_books = {
        {
            id = "doc1",
            metadata = {
                Title = "Foundation",
                Author = "Isaac Asimov",
                Series = "Foundation",
                Type = "book",
                Category = "science fiction",
                Language = "English",
                Year = "1951",
                Publisher = "Gnome Press",
                Pages = "244",
                Description = "First novel in the Foundation series about psychohistory"
            }
        },
        {
            id = "doc2", 
            metadata = {
                Title = "I Robot",
                Author = "Isaac Asimov",
                Series = "Robot",
                Type = "book", 
                Category = "science fiction",
                Language = "English",
                Year = "1950",
                Publisher = "Gnome Press",
                Pages = "253",
                Description = "Collection of robot stories with the Three Laws"
            }
        },
        {
            id = "doc3",
            metadata = {
                Title = "Le Petit Prince",
                Author = "Antoine de Saint-Exupéry",
                Type = "book",
                Category = "fiction",
                Language = "French", 
                Year = "1943",
                Publisher = "Reynal & Hitchcock",
                Pages = "96",
                Description = "A novella about a young prince who travels the universe"
            }
        },
        {
            id = "doc4",
            metadata = {
                Title = "Dune",
                Author = "Frank Herbert",
                Series = "Dune Chronicles",
                Type = "book",
                Category = "science fiction",
                Language = "English",
                Year = "1965", 
                Publisher = "Chilton Books",
                Pages = "688",
                Description = "Epic science fiction novel about desert planet Arrakis"
            }
        },
        {
            id = "doc5",
            metadata = {
                Title = "Machine Learning Basics",
                Author = "John Smith",
                Type = "textbook",
                Category = "computer science",
                Language = "English",
                Year = "2020",
                Publisher = "Tech Press",
                Pages = "450",
                Description = "Introduction to machine learning algorithms and techniques"
            }
        },
        {
            id = "doc5",
            metadata = {
                Title = "Machine Learning Basics",
                Author = "John Smith",
                Type = "textbook",
                Category = "computer science",
                Language = "English",
                Year = "2020",
                Publisher = "Tech Press",
                Pages = "450",
                Description = "Introduction to machine learning algorithms and techniques"
            }
        }
    }

    -- Add documents to search index
    for _, book in ipairs(sample_books) do
        search:add_document(book.id, book.metadata)
    end

    print("=== TF-IDF Document Search with Metadata and Filtering ===\n")

    -- Test 1: Basic search without filters
    print("Query: 'asimov robot'")
    local results = search:search("asimov robot", 3)

    -- Test 2: Search with language filter
    print("Query: 'science fiction' (English only)")
    local filters = { Language = "English" }
    results = search:search("science fiction", 3, filters)
    -- Test 3: Search with multiple filters
    print("Query: 'book' (English books from 1950s)")
    filters = { 
        Language = "English",
        Type = "book",
        Year = "1950" 
    }
    results = search:search("book", 3, filters)

    -- Test 4: Search with multiple language filter
    print("Query: 'fiction' (English or French)")
    filters = { 
        Language = {"English", "French"},
        Type = "book"
    }
    results = search:search("fiction", 5, filters)

    -- Test 5: Fuzzy search with typos
    print("Query: 'machne lerning' (with typos)")
    results = search:search("machne lerning", 3)

    -- Test 6: Category filtering
    print("Query: 'algorithms' (Computer Science only)")
    filters = { Category = "computer science" }
    results = search:search("algorithms", 3, filters)

    local ids = search:get_indexed_txs()
    print(table.concat(ids, ', '))

    math.randomseed(os.time())
    local random_results = search:get_random_documents(math.random(1,1000), 2)
    print(dump_table(random_results))
end

-- Run the example
example_usage()