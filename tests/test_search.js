

import fs from 'fs';
import { createDataItemSigner, message, result, dryrun } from '@permaweb/aoconnect';

// Configuration
//const PROCESS_ID = 'NoJOIG7obOoxaZ3qZiJ3ZOSAzVY_nZfRZ3WGHFXmXbc'; // libgen books
const PROCESS_ID = 'Yq0RHvqxlVOCnRfNKRNwCZHWEqK1-roiGhhjBMOLRdo' // images

const WALLET_PATH = '../utils/wallet.json'; // Path to your Arweave wallet JSON file
const TRANSACTIONS_FILE = './image_transactions.json';


async function Queue_document(tx) {
    const queue_message = await message({
      process: PROCESS_ID,
      tags: [
        { name: 'Action', value: 'Queue_document' }
      ],
      data: JSON.stringify(tx),
      signer: createDataItemSigner(JSON.parse(fs.readFileSync(WALLET_PATH, 'utf8')))// Pass wallet directly to createDataItemSigner
    });

    // Get the result to check for any errors
     const res = await result({
       message: queue_message,
       process: PROCESS_ID
    });
    console.log(res)

    return res
}

async function reset_index() {
    const clear_index_message = await message({
      process: PROCESS_ID,
      tags: [
        { name: 'Action', value: 'Reset_index' }
      ],
      data: '',
      signer: createDataItemSigner(JSON.parse(fs.readFileSync(WALLET_PATH, 'utf8')))// Pass wallet directly to createDataItemSigner
    });

    // Get the result to check for any errors
     const clear_index_result = await result({
       message: clear_index_message,
       process: PROCESS_ID
    });
    console.log(clear_index_result)
    return clear_index_result
}

async function search(query) {
    const filters = { 'Content-Type' : '"application/pdf"'}
    const search_resp = await dryrun({
       process: PROCESS_ID,
       tags: [
         { name: 'Action', value: 'Search_document' }
       ],
       data: JSON.stringify({query : 'cyborg', filters : filters}),
    });

    console.log(search_resp)
    const sr = JSON.parse(search_resp.Messages[0].Data)
    console.log(sr)
    return sr
}

async function get_idx() {
    const get_idx_resp = await dryrun({
       process: PROCESS_ID,
       tags: [
         { name: 'Action', value: 'Get_indexed_txs' }
       ],
       data: '',
    });

    console.log(get_idx_resp)

    const idx_result = JSON.parse(get_idx_resp.Messages[0].Data)
    console.log(idx_result)
    return idx_result
}

async function get_random_docs(n) {
    
    const seed = Math.floor(Math.random() * 1000)
    console.log(' random seed : ', seed)
    const random_doc_resp = await dryrun({
       process: PROCESS_ID,
       tags: [
         { name: 'Action', value: 'Get_random_documents' }
       ],
       data: JSON.stringify({seed : seed, n : n }),
    });

    console.log(random_doc_resp)
    console.log(JSON.stringify(random_doc_resp, null, 2))
    const random_doc_result = JSON.parse(random_doc_resp.Messages[0].Data)
    console.log(random_doc_result)
    return random_doc_result
}

async function main() {
  //await reset_index()
  await get_idx()
  await get_random_docs(2)
  
}

// Run the script
main();