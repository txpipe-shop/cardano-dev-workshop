use aiken/builtin.{slice_bytearray}
use cardano/assets.{
  ada_asset_name, ada_policy_id, from_asset, lovelace_of, match,
}
use cardano/transaction.{
  Datum, InlineDatum, Input, Output, OutputReference, Transaction, find_input,
}
use vodka_extra_signatories.{key_signed}

pub type VaultDatum {
  /// Beneficiary's credentials
  current_recipient: ByteArray,
}

// The Vault validator will be run whenever a Vault is spent. It checks:
//   1. The address of the vault input and vault output must match.
//   2. The current recipient must sign the transaction.
//   3. The output must have a valid datum.
//   4. The amount of ADA in the output must be at most half of the input amount.
validator vault {
  // Parameters:
  //   - datum: The datum of the vault being spent.
  //   - redeemer: The intent on which the is order being spent.
  //   - input_ref: The reference to the UTxO being spent.
  //   - tx: The information of the transaction which can be used to validate the spending of the vaults.
  spend(
    datum: Option<VaultDatum>,
    _redeemer: Data,
    input_ref: OutputReference,
    tx: Transaction,
  ) {
    // Destructure the datum to get the field we need.
    expect Some(datum) = datum
    let VaultDatum { current_recipient } = datum
    let recipient_payment_key = slice_bytearray(0, 28, current_recipient)

    // Look for the vault input and destructure its fields
    expect Some(vault_input) =
      tx.inputs
        |> find_input(input_ref)
    let Input {
      output: Output { address: in_address, value: in_value, .. },
      ..
    } = vault_input

    // We know the order of the outputs, so we can just access the index where we want the vault output:
    expect [vault_output, ..] = tx.outputs
    let Output { address: out_address, value: out_value, datum: out_datum, .. } =
      vault_output

    // We just make sure that the output has a valid datum. The current recipient is allowed to change the
    // next recipient.
    let VaultDatum { .. } = to_vault_datum(out_datum)

    // Make sure that the claim amount is at most half of the current locked amount.
    let current_locked = lovelace_of(in_value)
    let expected_remaining_value =
      from_asset(ada_policy_id, ada_asset_name, current_locked / 2)

    // Now perform the checks:
    and {
      (in_address == out_address)?,
      key_signed(tx.extra_signatories, recipient_payment_key)?,
      match(out_value, expected_remaining_value, >=)?,
    }
  }

  else(_) {
    fail
  }
}

pub fn to_vault_datum(data: Data) -> VaultDatum {
  expect InlineDatum(datum): Datum = data
  expect vault_datum: VaultDatum = datum
  vault_datum
}
