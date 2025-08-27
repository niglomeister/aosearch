# AOSearch

**A distributed search engine for the AO blockchain**

AOSearch is a comprehensive search solution built for the AO ecosystem that enables indexing and searching of Arweave transactions. The system consists of a main search process for handling queries and document indexing, a queue process for managing bulk indexing operations, and utility scripts for data management.

## Key Features

- **Full-text search** across indexed transaction data with configurable field filtering
- **Distributed architecture** with separate search and queue processes to handle high-volume indexing
- **Random document discovery** using RandAO integration for serendipitous content exploration  
- **Bulk indexing support** with retry mechanisms and failure handling
- **Authorization controls** for document indexing with configurable access permissions
- **Real-time search** with up to 40 results per query and optional result filtering
- **Queue management** with batch processing, status tracking, and automatic retries
- **Developer utilities** for uploading and downloading transaction data sets
- **Health monitoring** with ping endpoints and comprehensive status reporting

## Architecture Overview

AOSearch uses a multi-process architecture designed for scalability and reliability:

- **Search Process**: Core search engine that maintains the document index and handles search queries
- **Queue Process**: Manages bulk document indexing to prevent overwhelming the search process
- **Utility Scripts**: JavaScript tools for data import/export and process management
- **RandAO Integration**: Provides cryptographically secure randomness for document discovery

The processes communicate via AO's message-passing system, with the queue process acting as a buffer between bulk indexing operations and the search engine to ensure optimal performance.

---

## Table of Contents

1. [Project Header & Overview](#aosearch)
2. [Table of Contents](#table-of-contents)
3. [Getting Started](#getting-started)
4. [Architecture](#architecture)
5. [Core Processes](#core-processes)
   - 5.1 [Search Process](#search-process)
   - 5.2 [Queue Process](#queue-process)
6. [Utilities](#utilities)
   - 6.1 [Upload Script](#upload-script)
   - 6.2 [Download Script](#download-script)
7. [Examples & Use Cases](#examples--use-cases)
8. [Testing](#testing)
9. [License & Credits](#license--credits)

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

If you plan to do bulk indexing operations, deploy the queue process, if you are just looking to test or not looking to index large number of documents you can skip this step:

```bash
# Create another AO process  
aos queue-process

# Edit queue_process.lua and set TARGET_SEARCH_PROCESS to your search process ID
# Then load the queue code
.load queue_process.lua
```

### 3. Setup Utility Scripts

For the JavaScript utilities:

```bash
# Install dependencies
npm install

# Configure process IDs in the scripts
# Edit upload_to_index.js and set process_id to your search process ID
# Edit download_transactions.cjs and set process_id accordingly
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
- Ensure your `wallet.json` file is in the correct location for the upload script
- There are example transaction list files included already, edit the file path in upload_to_index.js if you want to use them

### 2. Verify Installation

After deployment, run the test suite to ensure everything is working correctly:

```bash
# Run tests to verify your setup
npm test
```


# Architecture

## System Overview

AOSearch implements a distributed architecture designed for scalability and reliability when handling large-scale document indexing and search operations on the AO blockchain.

## Core Components

### Search Process (`search_process.lua`)
The main search engine that provides:
- **Document Indexing**: Converts Arweave transactions into searchable documents
- **Full-Text Search**: Performs queries across indexed content with filtering capabilities  
- **Random Discovery**: Uses RandAO integration for random document retrieval ("im feeling lucky" style)
- **Authorization**: Controls access to indexing operations

### Queue Process (`queue_process.lua`)  
A optional buffering layer for large volume indexing that provides:
- **Bulk Processing**: Manages high-volume indexing without overwhelming the search process
- **Retry Logic**: Automatic retry mechanisms for failed indexing operations
- **Status Tracking**: Real-time monitoring of document processing states
- **Batch Management**: Configurable batch sizes and processing intervals
- **Error Handling**: Comprehensive failure management and reporting

### Utility Scripts
JavaScript tools for data management:
- **Download Script**: Download transaction data using graphql, to upload to the search process. You can get rate limited easily on arweave gateways so better download first and upload to the separately to not be subject to gateway errors during the upload
- **Upload Script**: Bulk uploads transaction data to the index from JSON file downloaded using the download script

## Data Flow

```
Transaction Data → Queue Process → Search Process → Indexed Documents
                      ↓              ↓
                 Status Tracking   Search Queries → Results
```

## Process Communication

The system uses AO's message-passing architecture:

- **External → Search**: Indexing, direct search queries and document retrieval requests
- **External → Queue**: Bulk indexing requests for large amounts of documents, as to not slow down the search process for users
- **Queue → Search**: `Index_document` messages with retry tracking via `Response-To` tags

## Scalability Design

- **Separation of Concerns**: Search and indexing operations are isolated to prevent performance interference
- **Batch Processing**: Queue process handles multiple documents efficiently
- **Configurable Limits**: Adjustable batch sizes, retry counts, and processing intervals


This architecture ensures AOSearch can handle both individual search queries with low latency and bulk indexing operations without compromising system performance or reliability.


# Core Processes

## 5.1 Search Process

The search process (`search_process.lua`) is the heart of AOSearch, providing document indexing, full-text search capabilities, and random document discovery.

### Purpose and Functionality

The search process maintains a searchable index of Arweave transactions and provides fast query capabilities. It converts transaction data into searchable documents, performs full-text searches with filtering, and integrates with RandAO for random document discovery.

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

## 5.2 Queue Process

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

## 6.1 Upload Script

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
# Set SEARCH_PROCESS_ID and QUEUE_PROCESS_ID
# Set USE_QUEUE = true for bulk operations

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
- Detailed error logging with transaction IDs
- Graceful handling of network issues
- Rate limiting protection with configurable delays

---

## 6.2 Download Script

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

**ArkiveNow Images:**
```javascript
const query = `
  query GetImages($cursor: String) {
    transactions(
      tags: [
        { name: "Content-Type", values: ["image/jpeg", "image/png", "image/gif", "image/webp"] }
        { name: "App-Name", values: "ArkiveNow" }
      ]
      first: 100
      after: $cursor
      sort: HEIGHT_DESC
    ) {
      // ... query structure
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

### Customization

To fetch different types of transactions, modify the `query` variable:

1. Change tag filters to match your target transactions
2. Adjust sorting and pagination parameters
3. Modify the selected fields in the GraphQL query
4. Update `maxTransactions` and `filename` as needed

The downloaded data can then be used with the upload script to populate your AOSearch index.

# Examples & Use Cases

## Common Search Patterns

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

## Bulk Indexing Workflows

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

## Integration Examples

### Academic Paper Repository
```javascript
// Index academic papers with rich metadata
const paperTransaction = {
  id: "paper-tx-id",
  tags: [
    {name: "Title", value: "Deep Learning Applications in Healthcare"},
    {name: "Author", value: "Dr. Jane Smith"},
    {name: "Category", value: "Computer Science"},
    {name: "Topic", value: "Machine Learning"},
    {name: "Year", value: "2024"},
    {name: "Publisher", value: "Academic Press"},
    {name: "Language", value: "English"}
  ]
};

// Search by research area
ao.send({
  Target: "search-process-id",
  Action: "Search_document",
  Data: JSON.stringify({
    query: "healthcare AI",
    filters: {"Category": "Computer Science", "Year": "2024"}
  })
});
```

### Digital Library System
```javascript
// Index books with library metadata
const bookTransaction = {
  id: "book-tx-id", 
  tags: [
    {name: "Title", value: "The Blockchain Revolution"},
    {name: "Author", value: "Alex Tapscott"},
    {name: "Category", value: "Technology"},
    {name: "Publisher", value: "Portfolio"},
    {name: "Year", value: "2016"},
    {name: "Extension", value: "pdf"},
    {name: "Language", value: "English"},
    {name: "Filesize", value: "2.5MB"}
  ]
};

// Search library catalog
ao.send({
  Target: "search-process-id",
  Action: "Search_document", 
  Data: JSON.stringify({
    query: "blockchain cryptocurrency",
    filters: {"Extension": "pdf", "Language": "English"}
  })
});
```

### Media Archive
```javascript
// Index multimedia content
const mediaTransaction = {
  id: "media-tx-id",
  tags: [
    {name: "Title", value: "Sunset Over Mountains"},
    {name: "Content-Type", value: "image/jpeg"},
    {name: "Author", value: "PhotoArtist"},
    {name: "Category", value: "Photography"},
    {name: "Topic", value: "Nature"},
    {name: "Year", value: "2024"},
    {name: "Filesize", value: "4.2MB"}
  ]
};

// Discover random media
ao.send({
  Target: "search-process-id",
  Action: "Get_random_documents",
  Data: JSON.stringify({n: 5})
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
