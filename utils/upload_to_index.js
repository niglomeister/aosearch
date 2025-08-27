import fs from 'fs';
import { createDataItemSigner, message, result } from '@permaweb/aoconnect';

// Configuration
const SEARCH_PROCESS_ID = '-O7VLCjzqvyqrmhWlIfwqp_DY2v8FmBVlBpOaDv8qlQ'; // Your search process ID
const QUEUE_PROCESS_ID = 'your-queue-process-id-here'; // Your queue process ID
const WALLET_PATH = './wallet.json'; // Path to your Arweave wallet JSON file
const TRANSACTIONS_FILE = './transactions.json';

// Configuration options
const USE_QUEUE = false; // Set to true to upload through the queue and to false to upload directly to search process
const BATCH_DELAY = 1000; // Delay between uploads in milliseconds

async function loadTransactions() {
  try {
    const data = fs.readFileSync(TRANSACTIONS_FILE, 'utf8');
    return JSON.parse(data);
  } catch (error) {
    console.error('Error loading transactions:', error);
    throw error;
  }
}

async function uploadToSearch(documentTransaction, index, total) {
  console.log(`[${index + 1}/${total}] Indexing document directly: ${documentTransaction.tags.find(t => t.name === 'Title')?.value || 'Unknown Title'}`);

  const messageId = await message({
    process: SEARCH_PROCESS_ID,
    tags: [
      { name: 'Action', value: 'Index_document' }
    ],
    data: JSON.stringify(documentTransaction),
    signer: createDataItemSigner(JSON.parse(fs.readFileSync(WALLET_PATH, 'utf8')))
  });

  console.log(`✓ Message sent: ${messageId}`);

  const res = await result({
    message: messageId,
    process: SEARCH_PROCESS_ID
  });

  if (res.Error) {
    console.error(`✗ Error processing document: ${res.Error}`);
    return { success: false, error: res.Error };
  }

  console.log(`✓ Document indexed successfully`);
  return { success: true, messageId };
}

async function uploadToQueue(documentTransaction, index, total) {
  console.log(`[${index + 1}/${total}] Queueing document: ${documentTransaction.tags.find(t => t.name === 'Title')?.value || 'Unknown Title'}`);

  const messageId = await message({
    process: QUEUE_PROCESS_ID,
    tags: [
      { name: 'Action', value: 'Queue_document' }
    ],
    data: JSON.stringify(documentTransaction),
    signer: createDataItemSigner(JSON.parse(fs.readFileSync(WALLET_PATH, 'utf8')))
  });

  console.log(`✓ Message sent: ${messageId}`);

  const res = await result({
    message: messageId,
    process: QUEUE_PROCESS_ID
  });

  if (res.Error) {
    console.error(`✗ Error queueing document: ${res.Error}`);
    return { success: false, error: res.Error };
  }

  const response = JSON.parse(res.Messages[0].Data);
  console.log(`✓ Document queued successfully - Queue ID: ${response.queue_id}`);
  return { success: true, messageId, queueId: response.queue_id };
}

async function main() {
  try {
    console.log('Loading wallet and transactions...');
    console.log(`Upload mode: ${USE_QUEUE ? 'Queue Process' : 'Direct to Search'}`);

    const transactions = await loadTransactions();
    console.log(`Found ${transactions.length} document transactions to process`);

    const results = {
      success: 0,
      failed: 0,
      errors: [],
      queueIds: []
    };

    // Process documents with configurable delay
    for (let i = 0; i < transactions.length; i++) {
      const transaction = transactions[i];

      const uploadResult = USE_QUEUE 
        ? await uploadToQueue(transaction, i, transactions.length)
        : await uploadToSearch(transaction, i, transactions.length);

      if (uploadResult.success) {
        results.success++;
        if (uploadResult.queueId) {
          results.queueIds.push(uploadResult.queueId);
        }
      } else {
        results.failed++;
        results.errors.push({
          transaction: transaction.id,
          error: uploadResult.error
        });
      }

      // Add delay between requests
      if (i < transactions.length - 1) {
        await new Promise(resolve => setTimeout(resolve, BATCH_DELAY));
      }
    }

    console.log('\n=== Summary ===');
    console.log(`Successfully ${USE_QUEUE ? 'queued' : 'indexed'}: ${results.success}`);
    console.log(`Failed: ${results.failed}`);

    if (USE_QUEUE && results.queueIds.length > 0) {
      console.log(`\nQueue IDs generated: ${results.queueIds.length}`);
      // Save queue IDs for tracking
      fs.writeFileSync('./queue_ids.json', JSON.stringify(results.queueIds, null, 2));
      console.log('Queue IDs saved to queue_ids.json');
    }

    if (results.errors.length > 0) {
      console.log('\nErrors:');
      results.errors.forEach(err => {
        console.log(`- Transaction ${err.transaction}: ${err.error}`);
      });
    }

  } catch (error) {
    console.error('Script failed:', error);
    process.exit(1);
  }
}

// Run the script
main();