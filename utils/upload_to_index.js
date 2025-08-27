import fs from 'fs';
import { createDataItemSigner, message, result } from '@permaweb/aoconnect';

// Configuration
const PROCESS_ID = '-O7VLCjzqvyqrmhWlIfwqp_DY2v8FmBVlBpOaDv8qlQ' //libgen books 
//const PROCESS_ID = 'Yq0RHvqxlVOCnRfNKRNwCZHWEqK1-roiGhhjBMOLRdo' // images
const WALLET_PATH = './wallet.json'; // Path to your Arweave wallet JSON file
const TRANSACTIONS_FILE = './libgen_transactions.json';


async function loadTransactions() {
  try {
    const data = fs.readFileSync(TRANSACTIONS_FILE, 'utf8');
    return JSON.parse(data);
  } catch (error) {
    console.error('Error loading transactions:', error);
    throw error;
  }
}

async function Indexdocument(documentTransaction, index, total) {
    console.log(`[${index + 1}/${total}] Queueing document: ${documentTransaction.tags.find(t => t.name === 'Title')?.value || 'Unknown Title'}`);

    console.log(documentTransaction)

    const messageId = await message({
      process: PROCESS_ID,
      tags: [
        { name: 'Action', value: 'Index_document' }
      ],
      data: JSON.stringify(documentTransaction),
      signer: createDataItemSigner(JSON.parse(fs.readFileSync(WALLET_PATH, 'utf8')))// Pass wallet directly to createDataItemSigner
    });

    console.log(`✓ Message sent: ${messageId}`);

    // Get the result to check for any errors
     const res = await result({
       message: messageId,
       process: PROCESS_ID
    });
     console.log(res)

    if (res.Error) {
     console.error(`✗ Error processing document: ${res.Error}`);
      return { success: false, error: res.Error };
     }

    console.log(`✓ document queued successfully`);
    return { success: true, messageId };

}

async function main() {
  try {
    console.log('Loading wallet and transactions...');

    const transactions = await loadTransactions();

    console.log(`Found ${transactions.length} document transactions to process`);

    const results = {
      success: 0,
      failed: 0,
      errors: []
    };

    // Process documents with a small delay to avoid overwhelming the network
    for (let i = 0; i < transactions.length; i++) {
      const transaction = transactions[i];
      const result = await IndexDocument(transaction, i, transactions.length);

      if (result.success) {
        results.success++;
      } else {
        results.failed++;
        results.errors.push({
          transaction: transaction.id,
          error: result.error
        });
      }

      // Add a small delay between requests (1 second) to avoide getting rape limited
      if (i < transactions.length - 1) {
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
    }

    console.log('\n=== Summary ===');
    console.log(`Successfully queued: ${results.success}`);
    console.log(`Failed: ${results.failed}`);

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