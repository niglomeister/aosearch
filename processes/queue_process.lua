local json = require('json')
local randomModule = require('random')(json)

-- Queue state
Queue = Queue or {}
QueueStatus = QueueStatus or {}
ProcessedCount = ProcessedCount or 0
FailedCount = FailedCount or 0

TARGET_SEARCH_PROCESS = TARGET_SEARCH_PROCESS or nil -- Set this to your search process ID
MAX_RETRIES = MAX_RETRIES or 3
BATCH_SIZE = BATCH_SIZE or 10
PROCESSING_INTERVAL = PROCESSING_INTERVAL or 5000 -- milliseconds

STATUS = {
    QUEUED = "QUEUED",
    PROCESSING = "PROCESSING", 
    INDEXED = "INDEXED",
    FAILED = "FAILED",
    RETRYING = "RETRYING"
}

-- Initialize random callback for queue processing
CallbackId = randomModule.generateUUID()
randomModule.requestRandom(CallbackId)
print('Queue process initialized, requesting random seed')

-- Add document to queue
Handlers.add(
    "queue_document", 
    Handlers.utils.hasMatchingTag("Action", "Queue_document"),
    function(msg)
        if not msg.Data then
            ao.send({Target = msg.From, Data = json.encode({error = "No document data provided"})})
            return
        end

        local document_data = json.decode(msg.Data)
        local queue_id = generate_queue_id()

        Queue[queue_id] = {
            id = queue_id,
            document = document_data,
            submitter = msg.From,
            timestamp = msg.Timestamp,
            retries = 0,
            last_attempt = nil,
            error_msg = nil
        }

        QueueStatus[queue_id] = STATUS.QUEUED

        ao.send({
            Target = msg.From, 
            Data = json.encode({
                success = true,
                queue_id = queue_id,
                status = STATUS.QUEUED,
                message = "Document added to indexing queue"
            })
        })

        print("Document queued with ID: " .. queue_id)
    end
)

-- Process next batch of queued documents
Handlers.add(
    "process_queue",
    Handlers.utils.hasMatchingTag("Action", "Process_queue"),
    function(msg)
        if not TARGET_SEARCH_PROCESS then
            ao.send({Target = msg.From, Data = json.encode({error = "TARGET_SEARCH_PROCESS not configured"})})
            return
        end

        local processed = process_next_batch()
        ao.send({
            Target = msg.From,
            Data = json.encode({
                processed = processed,
                queue_size = get_queue_size(),
                message = "Batch processing completed"
            })
        })
    end
)

-- Get queue status
Handlers.add(
    "get_queue_status",
    Handlers.utils.hasMatchingTag("Action", "Get_queue_status"),
    function(msg)
        local args = msg.Data and json.decode(msg.Data) or {}
        local queue_id = args.queue_id

        if queue_id then
            -- Get specific document status
            local item = Queue[queue_id]
            if item then
                ao.send({
                    Target = msg.From,
                    Data = json.encode({
                        queue_id = queue_id,
                        status = QueueStatus[queue_id],
                        document = item.document,
                        submitter = item.submitter,
                        timestamp = item.timestamp,
                        retries = item.retries,
                        last_attempt = item.last_attempt,
                        error_msg = item.error_msg
                    })
                })
            else
                ao.send({Target = msg.From, Data = json.encode({error = "Queue ID not found"})})
            end
        else
            -- Get overall queue statistics
            local stats = get_queue_statistics()
            ao.send({Target = msg.From, Data = json.encode(stats)})
        end
    end
)

-- Get all queued documents
Handlers.add(
    "get_queue_items",
    Handlers.utils.hasMatchingTag("Action", "Get_queue_items"),
    function(msg)
        local args = msg.Data and json.decode(msg.Data) or {}
        local status_filter = args.status
        local limit = args.limit or 50
        local offset = args.offset or 0

        local items = {}
        local count = 0

        for queue_id, item in pairs(Queue) do
            if not status_filter or QueueStatus[queue_id] == status_filter then
                if count >= offset and #items < limit then
                    table.insert(items, {
                        queue_id = queue_id,
                        status = QueueStatus[queue_id],
                        document_id = item.document.id,
                        submitter = item.submitter,
                        timestamp = item.timestamp,
                        retries = item.retries,
                        error_msg = item.error_msg
                    })
                end
                count = count + 1
            end
        end

        ao.send({
            Target = msg.From,
            Data = json.encode({
                items = items,
                total = count,
                offset = offset,
                limit = limit
            })
        })
    end
)

-- Handle indexing responses from search process
Handlers.add(
    "indexing_response",
    function(msg)
        return msg.From == TARGET_SEARCH_PROCESS and msg.Tags["Response-To"]
    end,
    function(msg)
        local queue_id = msg.Tags["Response-To"]
        local success = msg.Data == "document indexed"

        if Queue[queue_id] then
            if success then
                QueueStatus[queue_id] = STATUS.INDEXED
                ProcessedCount = ProcessedCount + 1
                print("Document successfully indexed: " .. queue_id)

                -- Notify submitter
                ao.send({
                    Target = Queue[queue_id].submitter,
                    Data = json.encode({
                        queue_id = queue_id,
                        status = STATUS.INDEXED,
                        message = "Document successfully indexed"
                    })
                })
            else
                handle_indexing_failure(queue_id, msg.Data or "Unknown error")
            end
        end
    end
)

-- Retry failed documents
Handlers.add(
    "retry_failed",
    Handlers.utils.hasMatchingTag("Action", "Retry_failed"),
    function(msg)
        local retried = 0

        for queue_id, status in pairs(QueueStatus) do
            if status == STATUS.FAILED and Queue[queue_id].retries < MAX_RETRIES then
                QueueStatus[queue_id] = STATUS.QUEUED
                Queue[queue_id].error_msg = nil
                retried = retried + 1
            end
        end

        ao.send({
            Target = msg.From,
            Data = json.encode({
                retried = retried,
                message = "Failed documents re-queued for processing"
            })
        })
    end
)

-- Configure target search process
Handlers.add(
    "set_target_process",
    Handlers.utils.hasMatchingTag("Action", "Set_target_process"),
    function(msg)
        TARGET_SEARCH_PROCESS = msg.Data
        ao.send({
            Target = msg.From,
            Data = json.encode({
                target_process = TARGET_SEARCH_PROCESS,
                message = "Target search process updated"
            })
        })
    end
)

-- Auto-process timer (if supported by your AO environment)
Handlers.add(
    "auto_process_timer",
    Handlers.utils.hasMatchingTag("Action", "Cron"),
    function(msg)
        if TARGET_SEARCH_PROCESS and get_queued_count() > 0 then
            process_next_batch()
        end
    end
)

-- Random number handler for queue processing
Handlers.add(
    "RandomResponse",
    Handlers.utils.hasMatchingTag("Action", "Random-Response"), 
    function(msg)
        local callbackId, entropy = randomModule.processRandomResponse(msg.From, msg.Data)
        print("Random seed received for queue: " .. tostring(entropy))
    end
)

function generate_queue_id()
    return "queue_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
end

function process_next_batch()
    if not TARGET_SEARCH_PROCESS then
        print("No target search process configured")
        return 0
    end

    local processed = 0
    local batch_count = 0

    for queue_id, item in pairs(Queue) do
        if QueueStatus[queue_id] == STATUS.QUEUED and batch_count < BATCH_SIZE then
            QueueStatus[queue_id] = STATUS.PROCESSING
            Queue[queue_id].last_attempt = os.time()
            Queue[queue_id].retries = Queue[queue_id].retries + 1

            ao.send({
                Target = TARGET_SEARCH_PROCESS,
                Action = "Index_document",
                Data = json.encode(item.document),
                Tags = {
                    ["Response-To"] = queue_id
                }
            })

            processed = processed + 1
            batch_count = batch_count + 1
        end
    end

    print("Processed batch of " .. processed .. " documents")
    return processed
end

function handle_indexing_failure(queue_id, error_msg)
    local item = Queue[queue_id]

    if item.retries >= MAX_RETRIES then
        QueueStatus[queue_id] = STATUS.FAILED
        FailedCount = FailedCount + 1
        Queue[queue_id].error_msg = error_msg

        -- Notify submitter of failure
        ao.send({
            Target = item.submitter,
            Data = json.encode({
                queue_id = queue_id,
                status = STATUS.FAILED,
                error = error_msg,
                message = "Document indexing failed after " .. MAX_RETRIES .. " attempts"
            })
        })
    else
        QueueStatus[queue_id] = STATUS.RETRYING
        Queue[queue_id].error_msg = error_msg

        -- Schedule retry (in a real implementation, you might want a delay)
        QueueStatus[queue_id] = STATUS.QUEUED
    end
end

function get_queue_size()
    local count = 0
    for _ in pairs(Queue) do
        count = count + 1
    end
    return count
end

function get_queued_count()
    local count = 0
    for _, status in pairs(QueueStatus) do
        if status == STATUS.QUEUED then
            count = count + 1
        end
    end
    return count
end

function get_queue_statistics()
    local stats = {
        total = 0,
        queued = 0,
        processing = 0,
        indexed = 0,
        failed = 0,
        retrying = 0
    }

    for _, status in pairs(QueueStatus) do
        stats.total = stats.total + 1
        if status == STATUS.QUEUED then
            stats.queued = stats.queued + 1
        elseif status == STATUS.PROCESSING then
            stats.processing = stats.processing + 1
        elseif status == STATUS.INDEXED then
            stats.indexed = stats.indexed + 1
        elseif status == STATUS.FAILED then
            stats.failed = stats.failed + 1
        elseif status == STATUS.RETRYING then
            stats.retrying = stats.retrying + 1
        end
    end

    stats.processed_count = ProcessedCount
    stats.failed_count = FailedCount

    return stats
end

print("Document Queue Process initialized")
print("Available actions:")
print("- Queue_document: Add document to indexing queue")
print("- Process_queue: Process next batch of queued documents") 
print("- Get_queue_status: Get queue statistics or specific document status")
print("- Get_queue_items: Get list of queued documents with optional filtering")
print("- Retry_failed: Retry failed documents")
print("- Set_target_process: Configure target search process ID")