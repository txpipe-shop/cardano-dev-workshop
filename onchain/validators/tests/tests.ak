use cardano/assets.{ada_asset_name, ada_policy_id, from_asset}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use mocktail.{add_extra_signatory, add_input, add_output, complete, mocktail_tx}
use mocktail/virgin_address.{mock_script_address}
use mocktail/virgin_key_hash.{mock_pub_key_hash}
use mocktail/virgin_output_reference.{mock_utxo_ref}
use vault.{VaultDatum}

// Example of unit tests for the Vault validator.
type TestCase {
  is_address_ok: Bool,
  is_signed_by_recipient: Bool,
  is_value_correct: Bool,
}

// Generate mock settings for the Vault validator tests.
// This function creates a mock transaction, datum and output reference based on the test case parameters.
fn mock_settings(
  test_case: TestCase,
) -> (OutputReference, VaultDatum, Transaction) {
  let datum = {
    let current_recipient = mock_pub_key_hash(0)
    VaultDatum { current_recipient }
  }

  // 10 ADA in lovelace
  let initial_lock = from_asset(ada_policy_id, ada_asset_name, 10000000)
  let output_reference = mock_utxo_ref(0, 1)

  let tx = {
    // Create a mock transaction with the given parameters.
    // The transaction will have a single output that represents the vault output.
    // The output will be created based on the test case parameters.

    let value_after_claim =
      from_asset(
        ada_policy_id,
        ada_asset_name,
        if test_case.is_value_correct {
          5000000
        } else {
          1000000
        },
      )

    // Different vault address for failure case
    let address =
      if test_case.is_address_ok {
        mock_script_address(0, None)
      } else {
        mock_script_address(1, None)
      }

    let vault_input =
      Input {
        output: Output {
          address: mock_script_address(0, None),
          value: initial_lock,
          datum: InlineDatum(datum),
          reference_script: None,
        },
        output_reference,
      }

    let vault_output =
      Output {
        address,
        value: value_after_claim,
        datum: InlineDatum(datum),
        reference_script: None,
      }

    mocktail_tx()
      |> complete()
      |> add_input(True, vault_input)
      |> add_output(True, vault_output)
      |> add_extra_signatory(
          test_case.is_signed_by_recipient,
          datum.current_recipient,
        )
  }
  (output_reference, datum, tx)
}

// Everything goes well
test success() {
  let test_case =
    TestCase {
      is_address_ok: True,
      is_signed_by_recipient: True,
      is_value_correct: True,
    }
  let (ref, datum, tx) = mock_settings(test_case)

  vault.vault.spend(Some(datum), Void, ref, tx)
}

// The payment value is incorrect
test fail_value() fail {
  let test_case =
    TestCase {
      is_address_ok: True,
      is_signed_by_recipient: True,
      is_value_correct: False,
    }
  let (ref, datum, tx) = mock_settings(test_case)

  vault.vault.spend(Some(datum), Void, ref, tx)
}

// The vault output is not at the correct address
test fail_address() fail {
  let test_case =
    TestCase {
      is_address_ok: False,
      is_signed_by_recipient: True,
      is_value_correct: True,
    }
  let (ref, datum, tx) = mock_settings(test_case)

  vault.vault.spend(Some(datum), Void, ref, tx)
}

test fail_not_signed() fail {
  let test_case =
    TestCase {
      is_address_ok: True,
      is_signed_by_recipient: False,
      is_value_correct: True,
    }
  let (ref, datum, tx) = mock_settings(test_case)

  vault.vault.spend(Some(datum), Void, ref, tx)
}
