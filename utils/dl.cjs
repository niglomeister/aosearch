const fs = require('fs');

/*
const query = `
  query GetLibgenTransactions($after: String) {
    transactions(
      tags: [
        {
          name: "App-Name"
          values: ["Libgen"]
        }
      ]
      first: 100
      after: $after
    ) {
      pageInfo {
        hasNextPage
      }
      edges {
        cursor
        node {
          id
          anchor
          signature
          recipient
          owner {
            address
            key
          }
          fee {
            winston
            ar
          }
          quantity {
            winston
            ar
          }
          data {
            size
            type
          }
          tags {
            name
            value
          }
          block {
            id
            timestamp
            height
            previous
          }
          bundledIn {
            id
          }
        }
      }
    }
  }
`;
*/

const query = `
query GetImages($cursor: String) {
    transactions(
        tags: [
            { name: "Content-Type", values: ["image/jpeg", "image/png", "image/gif", "image/webp"] }
            { name : "App-Name", values :"ArkiveNow" }
        ]
        first: 100
        after: $cursor
        sort: HEIGHT_DESC
    ) {
        pageInfo {
            hasNextPage
        }
        edges {
            cursor
            node {
                id
                owner {
                    address
                }
                tags {
                    name
                    value
                }
                block {
                    timestamp
                    height
                }
            }
        }
    }
}`;


const filename = 'image_transactions.json'

async function downloadTransactions() {
  const allTransactions = [];
  let after = null;
  let totalFetched = 0;

  while (totalFetched < 100) {
    const variables = after ? { after } : {};

    const response = await fetch('https://arweave.net/graphql', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        query,
        variables
      })
    });

    const result = await response.json();

    if (result.errors) {
      console.error('GraphQL errors:', result.errors);
      break;
    }

    const transactions = result.data.transactions.edges.map(edge => edge.node);
    const remainingNeeded = 200 - totalFetched;
    const transactionsToAdd = transactions.slice(0, remainingNeeded);

    allTransactions.push(...transactionsToAdd);
    totalFetched += transactionsToAdd.length;

    console.log(`Fetched ${totalFetched}/200 transactions`);

    if (!result.data.transactions.pageInfo.hasNextPage || totalFetched >= 200) {
      break;
    }

    after = result.data.transactions.edges[result.data.transactions.edges.length - 1].cursor;
  }
  
  return allTransactions;
}

// Run the script and save to file
downloadTransactions()
  .then(transactions => {
    console.log(`\nDownloaded ${transactions.length} Libgen transactions`);

    // Write to JSON file
    fs.writeFileSync(filename, JSON.stringify(transactions, null, 2));
    console.log(`Transactions saved to ${filename}`);
  })
  .catch(error => {
    console.error('Error downloading transactions:', error);
  });
