-- TF-IDF Document Search with Fuzzy Finding using fzy library
-- Requires: fzy library (https://github.com/swarn/fzy-lua)

local fzy = require('fzy')

local DocumentSearch = {}
DocumentSearch.__index = DocumentSearch

-- Create a new document search instance
function DocumentSearch.new(options)
    local self = setmetatable({}, DocumentSearch)
    self.documents = {}
    self.document_ids = {}
    self.vocabulary = {}
    self.idf_cache = {}

    -- Configuration options
    options = options or {}
    self.fuzzy_threshold = options.fuzzy_threshold or 0.3
    self.fuzzy_weight = options.fuzzy_weight or 0.4
    self.tfidf_weight = options.tfidf_weight or 0.6
    self.enable_fuzzy = options.enable_fuzzy ~= false -- default true

    return self
end

-- Tokenize text into words (simple whitespace splitting)
function DocumentSearch:tokenize(text)
    local words = {}
    for word in string.gmatch(string.lower(text), "%w+") do
        table.insert(words, word)
    end
    return words
end

-- Calculate term frequency for a document
function DocumentSearch:calculate_tf(words)
    local tf = {}
    local total_words = #words

    -- Count word frequencies
    for _, word in ipairs(words) do
        tf[word] = (tf[word] or 0) + 1
    end

    -- Normalize by total word count
    for word, count in pairs(tf) do
        tf[word] = count / total_words
    end

    return tf
end

-- Calculate inverse document frequency
function DocumentSearch:calculate_idf(term)
    if self.idf_cache[term] then
        return self.idf_cache[term]
    end

    local doc_count = 0
    local total_docs = #self.documents

    for _, doc in ipairs(self.documents) do
        if doc.tf[term] then
            doc_count = doc_count + 1
        end
    end

    local idf = 0
    if doc_count > 0 then
        idf = math.log(total_docs / doc_count)
    end

    self.idf_cache[term] = idf
    return idf
end

-- Find fuzzy matches for a query term in vocabulary
function DocumentSearch:find_fuzzy_matches(query_term, max_matches)
    max_matches = max_matches or 5
    local candidates = {}

    -- Collect all vocabulary terms as candidates
    for term, _ in pairs(self.vocabulary) do
        table.insert(candidates, term)
    end

    if #candidates == 0 then
        return {}
    end

    -- Use fzy to score and rank candidates
    local scored_matches = {}
    for _, candidate in ipairs(candidates) do
        if fzy.has_match(query_term, candidate) then
            local score = fzy.score(query_term, candidate)
            if score >= self.fuzzy_threshold then
                table.insert(scored_matches, {
                    term = candidate,
                    score = score,
                    positions = fzy.positions(query_term, candidate)
                })
            end
        end
    end

    -- Sort by fuzzy score (higher is better)
    table.sort(scored_matches, function(a, b) 
        return a.score > b.score 
    end)

    -- Return top matches
    local matches = {}
    for i = 1, math.min(max_matches, #scored_matches) do
        table.insert(matches, scored_matches[i])
    end

    return matches
end


function DocumentSearch:expand_query_terms(query_words)
    local expanded_terms = {}

    for _, query_word in ipairs(query_words) do
        -- Always include the original term with highest score
        expanded_terms[query_word] = {
            term = query_word,
            score = 1.0,  -- Exact match gets perfect score
            is_original = true
        }

        if self.enable_fuzzy then
            -- Add fuzzy matches with normalized scores
            local fuzzy_matches = self:find_fuzzy_matches(query_word, 3)
            for _, match in ipairs(fuzzy_matches) do
                if not expanded_terms[match.term] then
                    -- Normalize fuzzy score to be less than 1.0
                    local normalized_score = 0.5 + (0.4 * math.log(match.score + 1) / math.log(5))
                    expanded_terms[match.term] = {
                        term = match.term,
                        score = normalized_score,
                        is_original = false,
                        original_query = query_word
                    }
                end
            end
        end
    end

    return expanded_terms
end

-- Create searchable text from metadata
function DocumentSearch:create_searchable_text(metadata)
    local text_parts = {}

    for field, value in pairs(metadata) do
        if value and value ~= '' then
            -- Convert to string if not already
            if type(value) ~= 'string' then
                value = tostring(value)
            end
            table.insert(text_parts, value)
        end
    end

    return table.concat(text_parts, ' ')
end

-- Check if document matches filters
function DocumentSearch:matches_filters(doc, filters)
    if not filters or not doc.metadata then
        return true
    end

    for field, expected_value in pairs(filters) do
        local actual_value = doc.metadata[field]

        if type(expected_value) == "table" then
            -- Handle multiple values: { Language = { "English", "French" } }
            local found = false
            for _, value in ipairs(expected_value) do
                if actual_value == value then
                    found = true
                    break
                end
            end
            if not found then
                return false
            end
        else
            -- Simple equality check
            if actual_value ~= expected_value then
                return false
            end
        end
    end

    return true
end

-- Add a document to the search index
function DocumentSearch:add_document(id, metadata)
    if self.document_ids[id] ~= nil then
        print('doc alreay indexed, skipping')
        return
    end
    -- Create searchable text from metadata
    local text = self:create_searchable_text(metadata)
    local words = self:tokenize(text)
    local tf = self:calculate_tf(words)

    local document = {
        id = id,
        text = text,
        words = words,
        tf = tf,
        metadata = metadata
    }

    table.insert(self.documents, document)
    self.document_ids[id] = #self.documents

    -- Update vocabulary
    for word, _ in pairs(tf) do
        self.vocabulary[word] = true
    end

    -- Clear IDF cache since we added a new document
    self.idf_cache = {}
end

function DocumentSearch:get_indexed_txs()
    local indexed_txs = {}
    for id, _ in pairs(self.document_ids) do
        table.insert(indexed_txs, id)
    end
    return indexed_txs
end

function DocumentSearch:get_random_documents(seed, n)
    local results = {}
    local value = seed + 1
    for i = 1, n, 1 do
        value = (value * 9301 + 49297) % 233280
        local idx = (value % #self.documents) + 1

        table.insert( results, self.documents[idx])
    end
    return results
end

-- Calculate TF-IDF score for a term in a document
function DocumentSearch:calculate_tfidf(doc_index, term)
    local doc = self.documents[doc_index]
    local tf = doc.tf[term] or 0
    local idf = self:calculate_idf(term)
    return tf * idf
end

-- Calculate hybrid similarity (TF-IDF + fuzzy matching)
function DocumentSearch:hybrid_similarity(expanded_query_terms, doc_index)
    local doc = self.documents[doc_index]
    local tfidf_score = 0
    local fuzzy_score = 0
    local query_magnitude = 0
    local doc_magnitude = 0

    -- Calculate TF-IDF component
    for term, term_info in pairs(expanded_query_terms) do
        local doc_tfidf = self:calculate_tfidf(doc_index, term)
        local query_tfidf = term_info.score -- Use fuzzy score as query weight

        tfidf_score = tfidf_score + (query_tfidf * doc_tfidf)
        query_magnitude = query_magnitude + (query_tfidf * query_tfidf)
        doc_magnitude = doc_magnitude + (doc_tfidf * doc_tfidf)

        -- Add fuzzy bonus for matched terms
        if doc.tf[term] and not term_info.is_original then
            fuzzy_score = fuzzy_score + (term_info.score * doc.tf[term])
        end
    end

    -- Add document terms not in expanded query
    for term, _ in pairs(doc.tf) do
        if not expanded_query_terms[term] then
            local doc_tfidf = self:calculate_tfidf(doc_index, term)
            doc_magnitude = doc_magnitude + (doc_tfidf * doc_tfidf)
        end
    end

    -- Normalize TF-IDF score
    query_magnitude = math.sqrt(query_magnitude)
    doc_magnitude = math.sqrt(doc_magnitude)

    local normalized_tfidf = 0
    if query_magnitude > 0 and doc_magnitude > 0 then
        normalized_tfidf = tfidf_score / (query_magnitude * doc_magnitude)
    end

    -- Combine TF-IDF and fuzzy scores
    local final_score = (self.tfidf_weight * normalized_tfidf) + 
                       (self.fuzzy_weight * fuzzy_score)

    return final_score, normalized_tfidf, fuzzy_score
end

-- Search documents using TF-IDF with fuzzy matching and filtering
function DocumentSearch:search(query, max_results, filters)
    max_results = max_results or 10

    local query_words = self:tokenize(query)
    local expanded_terms = self:expand_query_terms(query_words)

    -- Calculate similarity scores for all documents
    local results = {}
    for i, doc in ipairs(self.documents) do
        -- Apply filters first
        if self:matches_filters(doc, filters) then
            local total_score, tfidf_score, fuzzy_score = 
                self:hybrid_similarity(expanded_terms, i)

            if total_score > 0 then
                table.insert(results, {
                    id = doc.id,
                    text = doc.text,
                    score = total_score,
                    tfidf_score = tfidf_score,
                    fuzzy_score = fuzzy_score,
                    matched_terms = self:get_matched_terms(expanded_terms, doc),
                    metadata = doc.metadata
                })
            end
        end
    end

    -- Sort by score (descending)
    table.sort(results, function(a, b) return a.score > b.score end)

    -- Return top results
    local top_results = {}
    for i = 1, math.min(max_results, #results) do
        table.insert(top_results, results[i])
    end

    return top_results
end

-- Get matched terms for a document
function DocumentSearch:get_matched_terms(expanded_terms, doc)
    local matched = {}
    for term, term_info in pairs(expanded_terms) do
        if doc.tf[term] then
            table.insert(matched, {
                term = term,
                is_fuzzy = not term_info.is_original,
                original_query = term_info.original_query,
                fuzzy_score = term_info.score
            })
        end
    end
    return matched
end


return DocumentSearch