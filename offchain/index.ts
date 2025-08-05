import { Client } from "./protocol.js";
import { sha512 } from "@noble/hashes/sha2";
import * as ed from "@noble/ed25519";
import { U5C } from "@utxorpc/blaze-provider";
import { VKeyWitness } from "tx3-sdk/trp";
import "dotenv/config";
import { Address, NetworkId } from "@blaze-cardano/core";

ed.etc.sha512Sync = sha512;

const client = new Client({
  endpoint: "http://localhost:8164",
});

const BOB = {
  privateKey: process.env.BOB_PRIVATE_KEY!,
  address: process.env.BOB_ADDRESS!,
};

const provider = new U5C({
  url: "http://localhost:8164",
  network: NetworkId.Testnet,
});

function sign(txHash: string, hexKey: string): VKeyWitness {
  const toSign = ed.etc.hexToBytes(txHash);
  const key = ed.etc.hexToBytes(hexKey);
  const signature = ed.sign(toSign, key);

  return {
    type: "vkey",
    key: {
      content: ed.etc.bytesToHex(ed.getPublicKey(key)),
      encoding: "hex",
    },
    signature: {
      content: ed.etc.bytesToHex(signature),
      encoding: "hex",
    },
  };
}

console.log(BOB.address);
const bobPk = Address.fromBech32(BOB.address).getProps().paymentPart!.hash;

async function placeOrderFlow(): Promise<string> {
  console.log(
    await provider.getUnspentOutputs(Address.fromBech32(BOB.address))
  );

  const resolved = await client.placeOrderTx({
    maker: {
      type: "String",
      value: BOB.address,
    },
    offeredAmount: { type: "Int", value: 1_234_567n },
    offeredName: { type: "String", value: "" },
    offeredPolicy: { type: "String", value: "" },
    recipientPaymentKey: { type: "String", value: bobPk },
    requestedAmount: { type: "Int", value: 42_424_242n },
    requestedName: { type: "String", value: "" },
    requestedPolicy: { type: "String", value: "" },
  });

  console.log(resolved);

  const witness = await sign(resolved.hash, BOB.privateKey);

  await client.submit({
    tx: {
      content: resolved.tx,
      encoding: "hex",
    },
    witnesses: [witness],
  });

  return `${resolved.hash}#0`;
}

async function swapFlow(lockedUtxo: string) {
  const txid = Buffer.from(lockedUtxo.split("#")[0], "hex");
  const index = parseInt(lockedUtxo.split("#")[1]);

  const resolved = await client.swapTx({
    orderRef: {
      type: "UtxoRef",
      value: {
        txid,
        index,
      },
    },
    recipient: {
      type: "String",
      value: BOB.address,
    },
    requestedAmount: { type: "Int", value: 42_424_242n },
    requestedName: { type: "String", value: "" },
    requestedPolicy: { type: "String", value: "" },
    taker: {
      type: "String",
      value: BOB.address,
    },
  });

  console.log(resolved);

  const witness = await sign(resolved.hash, BOB.privateKey);

  await client.submit({
    tx: {
      content: resolved.tx,
      encoding: "hex",
    },
    witnesses: [witness],
  });

  console.log(`utxo ${resolved.tx}#0 unlocked`);
}

const lockedUtxo = await placeOrderFlow();

console.log(`utxo ${lockedUtxo} locked in order`);

// unlockFlow("abc#0");
