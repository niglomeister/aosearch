local json = require('json')
local DocumentSearch = require('search')
local randomModule = require('random')(json)


Search = Search or DocumentSearch:new() 


-- leave nil to index all tag fields 
Indexed_fields = {'Title', 'Content-Type', 'Description', 'Category', 'Content-Disposition', 'Type', 'Topic', 'Author', 'Series',
'Edition', 'Language', 'Year', 'Publisher', 'Extension', 'Locator', 'Commentary', 'Descr', 'Filesize'}

Authorized_uploaders = nil



Handlers.add(
    "queue_document",
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


Handlers.add(
    "search_document",
    Handlers.utils.hasMatchingTag("Action", "Search_document"),
    function(msg)
        local search_params = json.decode(msg.Data)
        local results = search_document(search_params.query, search_params.filters or {})
        ao.send({ Target = msg.From, Data = json.encode(results)})
    end
)

Handlers.add('get_random_documents',
    Handlers.utils.hasMatchingTag('Action', 'Get_random_documents'),
    function (msg)
        local args = json.decode(msg.Data)
        local n = args.n
        local seed = RandomSeed
                
        local results = Search:get_random_documents(seed, n)
        ao.send({Target = msg.From, Data = json.encode(results) })
    end)



CallbackId = randomModule.generateUUID()
randomModule.requestRandom(CallbackId)
--Status = randomModule.viewRandomStatus(CallbackId)
--print(Status)
print('requested random number from RandAO')

RandomSeed = 1984


Handlers.add(
    "RequestRandom",
    Handlers.utils.hasMatchingTag("Action", "Request-Random"),
    function(msg)
        print("RequestRandom handler entered")

        local callbackId = randomModule.generateUUID()
        randomModule.requestRandom(callbackId)
    end
)

-- Handler for random number responses
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
    end
)


Handlers.add('get_indexed_txs',
    Handlers.utils.hasMatchingTag('Action', 'Get_indexed_txs'),
    function (msg)
        local indexed_txs = Search:get_indexed_txs()
        ao.send({Target =  msg.From, Data = json.encode(indexed_txs)})
    end)

Handlers.add('reset_index',
    Handlers.utils.hasMatchingTag('Action', 'Reset_index'),
    function (msg)
        Search = DocumentSearch:new()
        ao.send({Target = msg.From, Data = 'index has been reset'})
    end)

function Tx_to_document(tx)
    local doc = {}
    
    for _, tag in ipairs(tx.tags) do
        if Indexed_fields == nil or Contains(Indexed_fields, tag.name) then
            doc[tag.name] = tag.value
        end
    end

    return doc
end

function index_document(id, document)
  local success, message = Search:add_document(id, document)
  print(message, success, id)
end


function search_document(query, filters)
  local r = Search:search( query , 40, filters)

  local results = {}
  for i, value in ipairs(r) do
    table.insert(results, value)
  end
  return results
end

function Contains(array, value)
    for _, v in ipairs(array) do
        if v == value then
            return true
        end
    end
    return false
end

-- basic handlers
Handlers.add(
    "info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Data = json.encode({
                Name = "Test Process",
                Description = "A simple test process for AO", 
                Owner = Owner,
                ProcessId = ao.id,
                Handlers = #Handlers.list,
                Timestamp = msg.Timestamp
            })
        })
    end
)

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



