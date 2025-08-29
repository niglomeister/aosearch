// test_aosearch.js - Complete AOSearch Test Suite
import { createDataItemSigner, message, result, spawn } from '@permaweb/aoconnect';
import fs from 'fs';

// Test Configuration
const WALLET_PATH = '../utils/wallet.json';
const TEST_TIMEOUT = 30000; // 30 seconds per test

// Test Data
const testTransactions = [
  {
    id: 'test-tx-1',
    tags: [
      { name: 'Title', value: 'Introduction to Blockchain Technology' },
      { name: 'Author', value: 'Alice Johnson' },
      { name: 'Category', value: 'Technology' },
      { name: 'Year', value: '2024' },
      { name: 'Language', value: 'English' }
    ]
  },
  {
    id: 'test-tx-2',
    tags: [
      { name: 'Title', value: 'Advanced Machine Learning Algorithms' },
      { name: 'Author', value: 'Bob Smith' },
      { name: 'Category', value: 'Computer Science' },
      { name: 'Year', value: '2023' },
      { name: 'Language', value: 'English' }
    ]
  },
  {
    id: 'test-tx-3',
    tags: [
      { name: 'Title', value: 'Quantum Computing Fundamentals' },
      { name: 'Author', value: 'Carol Davis' },
      { name: 'Category', value: 'Physics' },
      { name: 'Year', value: '2024' },
      { name: 'Language', value: 'English' }
    ]
  }
];

// Test Results Tracking
let testResults = {
  passed: 0,
  failed: 0,
  total: 0,
  failures: []
};

// put you process ids there
let searchProcessId = 'Jzu1uOdKJ00V-61pTlIFy7sNRA3vwqWBgHUgmA5i7h4';
let queueProcessId = '';
let signer = null;

// Utility Functions
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function sendMessage(processId, action, data = null, tags = []) {
  const messageId = await message({
    process: processId,
    tags: [
      { name: 'Action', value: action },
      ...tags
    ],
    data: data ? JSON.stringify(data) : undefined,
    signer
  });

  await sleep(2000); // Wait for processing

  const res = await result({
    message: messageId,
    process: processId
  });

  return { messageId, result: res };
}

function logTest(testName, passed, error = null) {
  testResults.total++;
  if (passed) {
    testResults.passed++;
    console.log(`✅ ${testName}`);
  } else {
    testResults.failed++;
    testResults.failures.push({ test: testName, error });
    console.log(`❌ ${testName}: ${error}`);
  }
}

// Test Functions

async function testSearchProcessHealth() {
  try {
    const { result: res } = await sendMessage(searchProcessId, 'Ping');
    const passed = res.Messages && res.Messages[0] && res.Messages[0].Data.includes('Pong');
    logTest('Search Process Health Check', passed, passed ? null : 'No pong response');
  } catch (error) {
    logTest('Search Process Health Check', false, error.message);
  }
}

async function testQueueProcessHealth() {
  try {
    const { result: res } = await sendMessage(queueProcessId, 'Get_queue_status');
    const passed = res.Messages && res.Messages[0] && res.Messages[0].Data;
    logTest('Queue Process Health Check', passed, passed ? null : 'No status response');
  } catch (error) {
    logTest('Queue Process Health Check', false, error.message);
  }
}

async function testDirectIndexing() {
  try {
    const { result: res } = await sendMessage(searchProcessId, 'Index_document', testTransactions[0]);
    const passed = res.Messages && res.Messages[0] && res.Messages[0].Data === 'document indexed';
    logTest('Direct Document Indexing', passed, passed ? null : 'Document not indexed');
  } catch (error) {
    logTest('Direct Document Indexing', false, error.message);
  }
}

async function testQueueIndexing() {
  try {
    // Set target search process in queue
    await sendMessage(queueProcessId, 'Set_target_process', null, []);
    await sleep(1000);

    // Queue a document
    const { result: res } = await sendMessage(queueProcessId, 'Queue_document', testTransactions[1]);

    let passed = false;
    if (res.Messages && res.Messages[0]) {
      const response = JSON.parse(res.Messages[0].Data);
      passed = response.success && response.queue_id;
    }

    logTest('Queue Document Addition', passed, passed ? null : 'Document not queued');

    if (passed) {
      // Process the queue
      await sleep(2000);
      const { result: processRes } = await sendMessage(queueProcessId, 'Process_queue');
      const processSucceeded = processRes.Messages && processRes.Messages[0];
      logTest('Queue Processing', processSucceeded, processSucceeded ? null : 'Queue processing failed');
    }
  } catch (error) {
    logTest('Queue Document Addition', false, error.message);
  }
}

async function testBasicSearch() {
  try {
    // Wait for indexing to complete
    await sleep(3000);

    const searchQuery = {
      query: 'blockchain technology',
      filters: {}
    };

    const { result: res } = await sendMessage(searchProcessId, 'Search_document', searchQuery);

    let passed = false;
    if (res.Messages && res.Messages[0]) {
      const results = JSON.parse(res.Messages[0].Data);
      passed = Array.isArray(results) && results.length > 0;
    }

    logTest('Basic Search Functionality', passed, passed ? null : 'No search results returned');
  } catch (error) {
    logTest('Basic Search Functionality', false, error.message);
  }
}

async function testFilteredSearch() {
  try {
    // Index another document for filtering
    await sendMessage(searchProcessId, 'Index_document', testTransactions[2]);
    await sleep(2000);

    const searchQuery = {
      query: 'quantum',
      filters: { Category: 'Physics' }
    };

    const { result: res } = await sendMessage(searchProcessId, 'Search_document', searchQuery);

    let passed = false;
    if (res.Messages && res.Messages[0]) {
      const results = JSON.parse(res.Messages[0].Data);
      passed = Array.isArray(results) && results.length > 0;
    }

    logTest('Filtered Search', passed, passed ? null : 'Filtered search failed');
  } catch (error) {
    logTest('Filtered Search', false, error.message);
  }
}

async function testRandomDocuments() {
  try {
    const { result: res } = await sendMessage(searchProcessId, 'Get_random_documents', { n: 2 });

    let passed = false;
    if (res.Messages && res.Messages[0]) {
      const results = JSON.parse(res.Messages[0].Data);
      passed = Array.isArray(results);
    }

    logTest('Random Document Retrieval', passed, passed ? null : 'Random documents not retrieved');
  } catch (error) {
    logTest('Random Document Retrieval', false, error.message);
  }
}

async function testGetIndexedTransactions() {
  try {
    const { result: res } = await sendMessage(searchProcessId, 'Get_indexed_txs');

    let passed = false;
    if (res.Messages && res.Messages[0]) {
      const results = JSON.parse(res.Messages[0].Data);
      passed = Array.isArray(results) && results.length > 0;
    }

    logTest('Get Indexed Transactions', passed, passed ? null : 'No indexed transactions returned');
  } catch (error) {
    logTest('Get Indexed Transactions', false, error.message);
  }
}

async function testQueueStatus() {
  try {
    const { result: res } = await sendMessage(queueProcessId, 'Get_queue_status');

    let passed = false;
    if (res.Messages && res.Messages[0]) {
      const status = JSON.parse(res.Messages[0].Data);
      passed = typeof status.total === 'number';
    }

    logTest('Queue Status Retrieval', passed, passed ? null : 'Queue status not retrieved');
  } catch (error) {
    logTest('Queue Status Retrieval', false, error.message);
  }
}

async function testQueueItems() {
  try {
    const { result: res } = await sendMessage(queueProcessId, 'Get_queue_items', { limit: 10 });

    let passed = false;
    if (res.Messages && res.Messages[0]) {
      const response = JSON.parse(res.Messages[0].Data);
      passed = Array.isArray(response.items);
    }

    logTest('Queue Items Retrieval', passed, passed ? null : 'Queue items not retrieved');
  } catch (error) {
    logTest('Queue Items Retrieval', false, error.message);
  }
}

async function testIndexReset() {
  try {
    const { result: res } = await sendMessage(searchProcessId, 'Reset_index');
    const passed = res.Messages && res.Messages[0] && res.Messages[0].Data === 'index has been reset';
    logTest('Index Reset', passed, passed ? null : 'Index not reset');
  } catch (error) {
    logTest('Index Reset', false, error.message);
  }
}

async function testSearchAfterReset() {
  try {
    await sleep(2000);
    const searchQuery = { query: 'blockchain', filters: {} };
    const { result: res } = await sendMessage(searchProcessId, 'Search_document', searchQuery);

    let passed = false;
    if (res.Messages && res.Messages[0]) {
      const results = JSON.parse(res.Messages[0].Data);
      passed = Array.isArray(results) && results.length === 0;
    }

    logTest('Search After Reset (Empty Results)', passed, passed ? null : 'Search should return empty after reset');
  } catch (error) {
    logTest('Search After Reset (Empty Results)', false, error.message);
  }
}

async function testErrorHandling() {
  try {
    // Test invalid JSON
    const messageId = await message({
      process: searchProcessId,
      tags: [{ name: 'Action', value: 'Index_document' }],
      data: 'invalid json',
      signer
    });

    await sleep(2000);
    const res = await result({ message: messageId, process: searchProcessId });

    const passed = res.Error || (res.Messages && res.Messages[0] && res.Messages[0].Data.includes('error'));
    logTest('Error Handling (Invalid JSON)', passed, passed ? null : 'Should handle invalid JSON gracefully');
  } catch (error) {
    logTest('Error Handling (Invalid JSON)', true, null); // Exception is expected
  }
}

// Setup and Teardown
async function setupTests() {
  console.log('🚀 Setting up AOSearch Test Suite...\n');

  try {
    // Load wallet
    signer = createDataItemSigner(JSON.parse(fs.readFileSync(WALLET_PATH, 'utf8')));
    console.log('✅ Wallet loaded');

    // Note: In a real test environment, you would spawn processes here
    // For this example, assume processes are already running


    console.log(`✅ Search Process ID: ${searchProcessId}`);
    console.log(`✅ Queue Process ID: ${queueProcessId}`);

    // Configure queue process
    const { result: configRes } = await sendMessage(queueProcessId, 'Set_target_process', searchProcessId);
    console.log('✅ Queue process configured\n');

  } catch (error) {
    console.error('❌ Setup failed:', error.message);
    process.exit(1);
  }
}

async function runTests() {
  console.log('🧪 Running AOSearch Test Suite...\n');

  const tests = [
    testSearchProcessHealth,
    testQueueProcessHealth,
    testDirectIndexing,
    testQueueIndexing,
    testBasicSearch,
    testFilteredSearch,
    testRandomDocuments,
    testGetIndexedTransactions,
    testQueueStatus,
    testQueueItems,
    testErrorHandling,
    testIndexReset,
    testSearchAfterReset
  ];

  for (const test of tests) {
    try {
      await test();
      await sleep(1000); // Brief pause between tests
    } catch (error) {
      logTest(test.name, false, `Test execution failed: ${error.message}`);
    }
  }
}

function printResults() {
  console.log('\n📊 Test Results Summary');
  console.log('========================');
  console.log(`Total Tests: ${testResults.total}`);
  console.log(`Passed: ${testResults.passed} ✅`);
  console.log(`Failed: ${testResults.failed} ❌`);
  console.log(`Success Rate: ${((testResults.passed / testResults.total) * 100).toFixed(1)}%`);

  if (testResults.failures.length > 0) {
    console.log('\n❌ Failed Tests:');
    testResults.failures.forEach(failure => {
      console.log(`  - ${failure.test}: ${failure.error}`);
    });
  }

  console.log('\n🎯 Test Suite Complete!');

  // Exit with error code if tests failed
  if (testResults.failed > 0) {
    process.exit(1);
  }
}

// Main execution
async function main() {
  try {
    await setupTests();
    await runTests();
    printResults();
  } catch (error) {
    console.error('💥 Test suite failed:', error);
    process.exit(1);
  }
}

// Run if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}

export {
  setupTests,
  runTests,
  printResults,
  testResults
};