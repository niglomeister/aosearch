# AOSearch

**A distributed search engine for the AO blockchain**

AOSearch is a search engine built for the AO ecosystem that enables indexing and searching of Arweave transactions. The system consists of a main search process for handling queries and document indexing, a queue process for managing bulk indexing operations, and utility scripts for data management.

## Key Features

- **Full-text search** across indexed transaction data with configurable field filtering and fuzzy finding
- **Distributed architecture** with separate search and queue processes to handle high-volume indexing
- **Random document discovery** using RandAO integration for random document retrival (think "i'm feeling lucky" buttons)
- **Bulk indexing support** with retry mechanisms and failure handling
- **Authorization controls** for document indexing with configurable access permissions
- **Developer utilities** for uploading and downloading transaction data sets

---

## Table of Contents

1. [Project Header & Overview](#aosearch)
2. [Table of Contents](#table-of-contents)
3. [Getting Started](#getting-started)
4. [Core Processes](#core-processes)
   - 4.1 [Search Process](#search-process)
   - 4.2 [Queue Process](#queue-process)
5. [Utilities](#utilities)
   - 5.1 [Download Script](#download-script)
   - 5.2 [Upload Script](#upload-script)
6. [Examples & Use Cases](#examples--use-cases)
7. [License & Credits](#license--credits)

# Getting Started

## Prerequisites

Before setting up AOSearch, ensure you have:

- **AOS CLI**: Required for deploying and managing AO processes
- **Node.js**: Any reasonably recent version for running utility scripts
- **Arweave Wallet**: A `wallet.json` keyfile is needed for uploading transactions with the utility scripts
- **AO/Arweave Knowledge**: Basic familiarity with AO message passing and Arweave ecosystem concepts

## Installation

### 1. Deploy the Search Process

First, create and deploy the main search process:

```bash
# Create a new AO process
aos search-process

# Load the search engine code
.load search_process.lua
```

**Note the Process ID** that gets generated - you'll need this for the opional queue process configuration and for running the utility scripts

### 2. Deploy the Queue Process (Optional)

If you plan to do bulk indexing operations, deploy the queue process, if you are just looking to test or not looking to index very large number of documents you can skip this step:

```bash
# Create another AO process  
aos queue-process

# Edit queue_process.lua and set TARGET_SEARCH_PROCESS to your search process ID
# Then load the queue code
.load queue_process.lua
```

### 3. Install javascript dependencies

For the JavaScript utilities:

```bash
# Install dependencies
npm install
```

## Quick Start

### 1. Configure Your Processes

**Search Process Configuration (Optional):**
- Edit `Indexed_fields` to specify which transaction tag fields to index
- Set `Authorized_uploaders` to control who can index documents (leave `nil` for open access)

**Queue Process Configuration (Required if using a separate queue process ):**
- Set `TARGET_SEARCH_PROCESS` to your search process ID

**Utility Scripts Configuration:**
- Set the `process_id` variable in both JavaScript files to your search process ID
- Ensure your `wallet.json` file is in the utils directory
- There are example transaction list files included already, edit the file path in upload_to_index.js if you want to use them

### 2. Verify Installation

After deployment, run the test suite to ensure everything is working correctly:

```bash
# Run tests to verify your setup
# set the process id variables inside the script to that of your search process and of your queue process if you are using one

node full_test.js
```

### 3. Index transactions and search

Once everything works you can configure and use the utility scripts described in section 5 to download and index transactions

Set the graphql query inside the script and download new transactions corresponding to your usecase, or just use the default
```bash
# Run tests to verify your setup
node download_transactions.cjs
```

Set the TRANSACTION_FILE variable to your JSON transations file path and the process ids to the ids of your corresponding processes, then run
```bash
# Run tests to verify your setup
node upload_to_index.js
```

# Core Processes

## 4.1 Search Process

The search process (`search_process.lua`) is the heart of AOSearch, providing document indexing, full-text search capabilities, and random document discovery.

### Purpose and Functionality

The search process maintains a searchable index of Arweave transactions and provides query capabilities. It converts transaction data into searchable documents, performs full-text searches with filtering, and integrates with RandAO for random document discovery.

### Configuration Options

#### Indexed Fields
```lua
Indexed_fields = {'Title', 'Content-Type', 'Description', 'Category', 'Content-Disposition', 'Type', 'Topic', 'Author', 'Series', 'Edition', 'Language', 'Year', 'Publisher', 'Extension', 'Locator', 'Commentary', 'Descr', 'Filesize'}
```
Controls which transaction tag fields are included in the search index. Set to `nil` to index all fields.

#### Authorization
```lua
Authorized_uploaders = nil
```
Array of addresses authorized to index documents. Set to `nil` for open access.

### Message Handlers

#### Index Document
**Action:** `Index_document`

Adds a new document to the search index from transaction data.

**Request:**
```json
{
  "Action": "Index_document",
  "Data": "{\"id\": \"tx123\", \"tags\": [{\"name\": \"Title\", \"value\": \"Document Title\"}]}"
}
```

**Response:**
- Success: `"document indexed"`
- Failure: Authorization error message

#### Search Documents
**Action:** `Search_document`

Performs full-text search with optional filters.

**Request:**
```json
{
  "Action": "Search_document",
  "Data": "{\"query\": \"blockchain\", \"filters\": {\"Category\": \"tech\"}}"
}
```

**Response:** JSON array of up to 40 search results

#### Get Random Documents
**Action:** `Get_random_documents`

Retrieves random documents using RandAO entropy.

**Request:**
```json
{
  "Action": "Get_random_documents",
  "Data": "{\"n\": 5}"
}
```

**Response:** JSON array of random documents

#### Index Management
- **Get_indexed_txs**: Returns all indexed transaction IDs
- **Reset_index**: Clears the entire search index
- **Ping**: Health check endpoint

### Performance Considerations

- Configurable field indexing to reduce storage overhead
- Efficient document-to-transaction conversion to trim unecessary data for indexing

---

## 4.2 Queue Process

The queue process (`queue_process.lua`) manages bulk document indexing operations, preventing the search process from being overwhelmed during high-volume uploads.

### Purpose and Functionality

Acts as a buffer between bulk indexing requests and the search process, providing retry mechanisms, batch processing, and comprehensive status tracking for document indexing operations.

### Configuration Options

```lua
TARGET_SEARCH_PROCESS = nil  -- Set to your search process ID
MAX_RETRIES = 3             -- Maximum retry attempts
BATCH_SIZE = 10             -- Documents per batch
PROCESSING_INTERVAL = 5000  -- Milliseconds between batches
```

### Queue States

Documents progress through these states:
- **QUEUED**: Waiting for processing
- **PROCESSING**: Currently being indexed
- **INDEXED**: Successfully added to search index
- **FAILED**: Exceeded retry limit
- **RETRYING**: Failed but will retry

### Message Handlers

#### Queue Document
**Action:** `Queue_document`

Adds a document to the indexing queue.

**Request:**
```json
{
  "Action": "Queue_document",
  "Data": "{\"id\": \"tx123\", \"tags\": [...]}"
}
```

**Response:**
```json
{
  "success": true,
  "queue_id": "queue_1234567890_5678",
  "status": "QUEUED",
  "message": "Document added to indexing queue"
}
```

#### Process Queue
**Action:** `Process_queue`

Manually triggers batch processing of queued documents.

**Response:**
```json
{
  "processed": 10,
  "queue_size": 45,
  "message": "Batch processing completed"
}
```

#### Queue Status
**Action:** `Get_queue_status`

Get overall queue statistics or specific document status.

**For specific document:**
```json
{
  "Action": "Get_queue_status",
  "Data": "{\"queue_id\": \"queue_1234567890_5678\"}"
}
```

**For overall statistics:**
```json
{
  "Action": "Get_queue_status"
}
```

**Response:**
```json
{
  "total": 100,
  "queued": 25,
  "processing": 5,
  "indexed": 65,
  "failed": 5,
  "processed_count": 65,
  "failed_count": 5
}
```

#### Queue Items
**Action:** `Get_queue_items`

Retrieve paginated list of queue items with optional filtering.

**Request:**
```json
{
  "Action": "Get_queue_items",
  "Data": "{\"status\": \"FAILED\", \"limit\": 20, \"offset\": 0}"
}
```

#### Management Actions
- **Retry_failed**: Re-queue failed documents for retry
- **Set_target_process**: Configure the target search process ID

### Retry Mechanisms and Error Handling

- **Automatic Retries**: Failed documents are automatically retried up to `MAX_RETRIES`
- **Exponential Backoff**: Failed documents can be manually re-queued
- **Error Tracking**: Detailed error messages stored for debugging
- **Batch Processing**: Configurable batch sizes prevent overwhelming the search process
- **Status Notifications**: Submitters receive notifications on success/failure

### Queue Processing Flow

1. Documents are added to queue with `QUEUED` status
2. Batch processor selects up to `BATCH_SIZE` queued documents
3. Documents marked as `PROCESSING` and sent to search process
4. Search process responds with success/failure
5. Queue updates status to `INDEXED` or handles retry logic
6. Submitters notified of final status

---

# Utilities

## 5.1 Download Script

The download script (`download_transactions.cjs`) queries Arweave's GraphQL endpoint to fetch transaction data and save it locally for processing.

### Purpose and Usage

Fetches transaction data from Arweave based on configurable GraphQL queries and saves the results to a JSON file. Includes example queries for different use cases and supports pagination for large datasets.

### Configuration

```javascript
const filename = 'transactions.json';  // Output filename
const maxTransactions = 200;           // Maximum transactions to fetch
```

### Query Examples

The script includes pre-configured queries for example use cases:

**Libgen Books:**
```javascript
const query = `
  query GetLibgenTransactions($after: String) {
    transactions(
      tags: [{ name: "App-Name", values: ["Libgen"] }]
      first: 100
      after: $after
    ) {
      pageInfo { hasNextPage }
      edges {
        cursor
        node {
          id
          tags { name value }
          block { timestamp height }
        }
      }
    }
  }
`;
```


### Command Line Usage

```bash
# Edit the query variable to match your needs
# Modify filename and maxTransactions as desired

# Run the download
node download_transactions.js
```

### Output Format

Creates a JSON file with an array of transaction objects:

```json
[
  {
    "id": "transaction-id",
    "owner": {"address": "owner-address"},
    "tags": [{"name": "tag-name", "value": "tag-value"}],
    "block": {"timestamp": 1234567890, "height": 12345}
  }
]
```


## 5.2 Upload Script

The upload script (`upload_to_index.js`) enables bulk uploading of transaction data to AOSearch, with support for both direct indexing and queue-based processing.

### Purpose and Usage

Reads transaction data from a JSON file and uploads it to either the search process directly or through the queue process for bulk operations. The script handles authentication, error management, and provides detailed progress reporting.

### Configuration

```javascript
// Process Configuration
const SEARCH_PROCESS_ID = 'your-search-process-id';  // Direct indexing target
const QUEUE_PROCESS_ID = 'your-queue-process-id';    // Queue process target
const WALLET_PATH = './wallet.json';                 // Arweave wallet keyfile
const TRANSACTIONS_FILE = './transactions.json';     // Input data file

// Upload Configuration  
const USE_QUEUE = true;        // true: use queue process, false: direct upload
const BATCH_DELAY = 1000;      // Milliseconds between uploads
```

### Options

The script can be configured by editing the constants at the top of the file:

- **USE_QUEUE**: Set to `true` for bulk operations via queue process, `false` for direct indexing
- **BATCH_DELAY**: Adjust delay between uploads to manage rate limiting
- **Process IDs**: Set your specific search and queue process IDs

### Input Format Requirements

The script expects a JSON file containing an array of Arweave transaction objects:

```json
[
  {
    "id": "transaction-id",
    "tags": [
      {"name": "Title", "value": "Document Title"},
      {"name": "Author", "value": "Author Name"},
      {"name": "Category", "value": "Category"}
    ],
    "owner": {"address": "owner-address"},
    "block": {"timestamp": 1234567890}
  }
]
```

### Example Usage

```bash
# Install dependencies
npm install

# Configure the script by editing the constants
# Set SEARCH_PROCESS_ID 
# Set QUEUE_PROCESS_ID if using one for bulk operations for bulk operations

# Run the upload
node upload_to_index.js
```

### Output and Tracking

**Direct Upload Mode:**
- Real-time progress reporting
- Success/failure summary
- Error details for failed uploads

**Queue Mode:**
- Progress reporting with queue IDs
- Queue IDs saved to `queue_ids.json` for tracking
- Summary of queued vs failed documents

### Error Handling

- Automatic retry logic (configurable delay)
- Graceful handling of network issues
- Rate limiting protection with configurable delays

---


# Example usecases

### Basic Text Search
```javascript
// Search for documents containing "blockchain"
ao.send({
  Target: "your-search-process-id",
  Action: "Search_document",
  Data: JSON.stringify({
    query: "blockchain technology"
  })
});
```

### Filtered Search
```javascript
// Search for research papers by a specific author
ao.send({
  Target: "your-search-process-id", 
  Action: "Search_document",
  Data: JSON.stringify({
    query: "machine learning",
    filters: {
      "Author": "John Doe",
      "Category": "Research",
      "Language": "English"
    }
  })
});
```

### Content Discovery
```javascript
// Get 10 random documents for content discovery
ao.send({
  Target: "your-search-process-id",
  Action: "Get_random_documents", 
  Data: JSON.stringify({n: 10})
});
```

## Indexing Workflows

### Small Dataset (Direct Upload)
For datasets under 100 documents, upload directly to the search process:

```bash
# Configure upload script
# Set USE_QUEUE = false in upload_to_index.js
# Set SEARCH_PROCESS_ID to your search process

node upload_to_index.js
```

### Large Dataset (Queue-Based)
For bulk operations with hundreds or thousands of documents:

```bash
# Configure for queue processing
# Set USE_QUEUE = true in upload_to_index.js  
# Set QUEUE_PROCESS_ID to your queue process

node upload_to_index.js

# Monitor queue progress
ao.send({
  Target: "your-queue-process-id",
  Action: "Get_queue_status"
});
```

### Queue Management Workflow
```javascript
// Check overall queue status
ao.send({
  Target: "queue-process-id",
  Action: "Get_queue_status"
});

// Get failed documents for review
ao.send({
  Target: "queue-process-id", 
  Action: "Get_queue_items",
  Data: JSON.stringify({
    status: "FAILED",
    limit: 20
  })
});

// Retry failed documents
ao.send({
  Target: "queue-process-id",
  Action: "Retry_failed"
});
```

---

# License & Credits

## License

AOSearch is released under the **MIT License**.

```
MIT License

Copyright (c) 2024 AOSearch Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
