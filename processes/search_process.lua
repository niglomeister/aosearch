--------------------------------------------------------------------------------
-- AO Document Search Process
-- Provides indexing and search capabilities for transactions on the AO blockchain:
--   • Index documents from transaction data with configurable field filtering
--   • Full-text search with optional filters
--   • Random document retrieval using RandAO integration
--   • Authorization controls for document indexing
--   • Index management and health monitoring
--------------------------------------------------------------------------------

local json = require('json')
local DocumentSearch = require('search')
local randomModule = require('random')(json)

--------------------------------------------------------------------------------
-- Initialize Core Components
--------------------------------------------------------------------------------
Search = Search or DocumentSearch:new() 

--------------------------------------------------------------------------------
-- Configuration Variables
--   Indexed_fields      : Array of transaction tag fields to include in search index
--                        Set to nil to index all tag fields
--   Authorized_uploaders: Array of addresses authorized to index documents
--                        Set to nil to allow anyone to index
--   RandomSeed         : Current random seed for document retrieval
--   CallbackId         : UUID for tracking random number requests
--------------------------------------------------------------------------------
-- Only these fields from the transaction tags will be included in the document, this is done to leave out fields like hashes or timestamps or any uneccesary fields that might pollute the search and take uneccesary space 
-- These should be tailored to your usecase, edit to your needs and choose which fields to consider for search before spawning the process  
-- leave nil to index all tag fields 
Indexed_fields = {'Title', 'Content-Type', 'Description', 'Category', 'Content-Disposition', 'Type', 'Topic', 'Author', 'Series',
'Edition', 'Language', 'Year', 'Publisher', 'Extension', 'Locator', 'Commentary', 'Descr', 'Filesize'}

-- You may not want anyone to be able to index documents on your process, replace with an array of authorized addresses if needed or leave nil if anyone can index.
Authorized_uploaders = nil

RandomSeed = 1984

--------------------------------------------------------------------------------
-- Handler: Index Document
-- Action: "Index_document"
-- Purpose: Adds a new document to the search index from transaction data
-- 
-- Request Data: JSON-encoded transaction object with 'id' and 'tags' fields
-- Authorization: Checks Authorized_uploaders if configured
-- 
-- Response: 
--   Success: "document indexed"
--   Failure: Authorization error message
--------------------------------------------------------------------------------
Handlers.add(
    "index_document",
    Handlers.utils.hasMatchingTag("Action", "Index_document"),
    function(msg)
        if Authorized_uploaders ~= nil and not Authorized_uploaders[msg.From] then
            ao.send({Target = msg.From, Data = 'sorry but your address is not authorized to upload documents to that index'})
            return
        end

        local tx = json.decode(msg.Data)
        local document = Tx_to_document(tx)
        index_document(tx.id, document)

        ao.send({Target = msg.From, Data = 'document indexed'})
    end)

--------------------------------------------------------------------------------
-- Handler: Search Documents
-- Action: "Search_document"
-- Purpose: Performs full-text search on indexed documents with optional filters
--
-- Request Data: JSON object with:
--   - query (string): Search query text
--   - filters (object, optional): Key-value pairs for filtering results
--
-- Response: JSON-encoded array of search results (max 40 results)
--------------------------------------------------------------------------------
Handlers.add(
    "search_document",
    Handlers.utils.hasMatchingTag("Action", "Search_document"),
    function(msg)
        local search_params = json.decode(msg.Data)
        local results = search_document(search_params.query, search_params.filters or {})
        ao.send({ Target = msg.From, Data = json.encode(results)})
    end
)

--------------------------------------------------------------------------------
-- Handler: Get Random Documents
-- Action: "Get_random_documents"
-- Purpose: Retrieves a random selection of documents from the index
--
-- Request Data: JSON object with:
--   - n (number): Number of random documents to retrieve
--
-- Response: JSON-encoded array of random documents
--------------------------------------------------------------------------------
Handlers.add('get_random_documents',
    Handlers.utils.hasMatchingTag('Action', 'Get_random_documents'),
    function (msg)
        local args = json.decode(msg.Data)
        local n = args.n
        local seed = RandomSeed

        local results = Search:get_random_documents(seed, n)
        ao.send({Target = msg.From, Data = json.encode(results) })
    end)

--------------------------------------------------------------------------------
-- Random Number Generation Setup
-- Initializes random number generation via RandAO for document randomization
--------------------------------------------------------------------------------
CallbackId = randomModule.generateUUID()
randomModule.requestRandom(CallbackId)
print('requested random number from RandAO')

--------------------------------------------------------------------------------
-- Handler: Request Random Number
-- Action: "Request-Random"
-- Purpose: Manually triggers a new random number request from RandAO
--
-- Request Data: None required
-- Response: Initiates random number generation process
--------------------------------------------------------------------------------
Handlers.add(
    "RequestRandom",
    Handlers.utils.hasMatchingTag("Action", "Request-Random"),
    function(msg)
        print("RequestRandom handler entered")

        local callbackId = randomModule.generateUUID()
        randomModule.requestRandom(callbackId)
    end
)

--------------------------------------------------------------------------------
-- Handler: Random Response Processor
-- Action: "Random-Response"
-- Purpose: Processes random number responses from RandAO and updates seed
--
-- Behavior: 
--   - Updates RandomSeed with new entropy value
--   - Automatically requests next random number for continuous refresh
--------------------------------------------------------------------------------
Handlers.add(
    "RandomResponse",
    Handlers.utils.hasMatchingTag("Action", "Random-Response"),
    function(msg)
        -- Process the random module's response
        local callbackId, entropy = randomModule.processRandomResponse(msg.From, msg.Data)
        print("Random Number Received!")
        print("CallbackId: " .. tostring(callbackId))
        print("Entropy: " .. tostring(entropy))

        RandomSeed = entropy
        ao.send({ Target = ao.id, Action = "Request-Random"})
    end
)

--------------------------------------------------------------------------------
-- Handler: Get Indexed Transactions
-- Action: "Get_indexed_txs"
-- Purpose: Returns list of all transaction IDs currently in the search index
--
-- Request Data: None required
-- Response: JSON-encoded array of indexed transaction IDs
--------------------------------------------------------------------------------
Handlers.add('get_indexed_txs',
    Handlers.utils.hasMatchingTag('Action', 'Get_indexed_txs'),
    function (msg)
        local indexed_txs = Search:get_indexed_txs()
        ao.send({Target =  msg.From, Data = json.encode(indexed_txs)})
    end)

--------------------------------------------------------------------------------
-- Handler: Reset Search Index
-- Action: "Reset_index"
-- Purpose: Clears the entire search index and creates a fresh empty index
--
-- Request Data: None required
-- Response: "index has been reset"
--------------------------------------------------------------------------------
Handlers.add('reset_index',
    Handlers.utils.hasMatchingTag('Action', 'Reset_index'),
    function (msg)
        Search = DocumentSearch:new()
        ao.send({Target = msg.From, Data = 'index has been reset'})
    end)

--------------------------------------------------------------------------------
-- Handler: Health Check
-- Action: "Ping"
-- Purpose: Verifies the process is alive and responsive
--
-- Request Data: None required
-- Response: "Pong! Process is alive at [timestamp]"
--------------------------------------------------------------------------------
Handlers.add(
    "ping",
    Handlers.utils.hasMatchingTag("Action", "Ping"),
    function(msg)
        ao.send({
            Target = msg.From,
            Data = "Pong! Process is alive at " .. tostring(msg.Timestamp)
        })
    end
)

--------------------------------------------------------------------------------
-- Core Helper Functions
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Tx_to_document(tx)
-- Converts a transaction object to a searchable document
-- Extracts only the tag fields specified in Indexed_fields configuration
--
-- Parameters:
--   tx (table): Transaction object with 'tags' array
--
-- Returns:
--   table: Document object with filtered tag fields as key-value pairs
--------------------------------------------------------------------------------
function Tx_to_document(tx)
    local doc = {}

    for _, tag in ipairs(tx.tags) do
        if Indexed_fields == nil or Contains(Indexed_fields, tag.name) then
            doc[tag.name] = tag.value
        end
    end

    return doc
end

--------------------------------------------------------------------------------
-- index_document(id, document)
-- Adds a document to the search index with the specified ID
--
-- Parameters:
--   id (string): Unique identifier for the document
--   document (table): Document object with searchable fields
--------------------------------------------------------------------------------
function index_document(id, document)
  local success, message = Search:add_document(id, document)
  print(message, success, id)
end

--------------------------------------------------------------------------------
-- search_document(query, filters)
-- Performs search query on indexed documents with optional filtering
--
-- Parameters:
--   query (string): Search query text
--   filters (table): Key-value pairs for filtering results
--
-- Returns:
--   table: Array of search results (maximum 40 results)
--------------------------------------------------------------------------------
function search_document(query, filters)
  local r = Search:search( query , 40, filters)

  local results = {}
  for i, value in ipairs(r) do
    table.insert(results, value)
  end
  return results
end

--------------------------------------------------------------------------------
-- Contains(array, value)
-- Utility function to check if an array contains a specific value
--
-- Parameters:
--   array (table): Array to search in
--   value (any): Value to search for
--
-- Returns:
--   boolean: true if value is found, false otherwise
--------------------------------------------------------------------------------
function Contains(array, value)
    for _, v in ipairs(array) do
        if v == value then
            return true
        end
    end
    return false
end