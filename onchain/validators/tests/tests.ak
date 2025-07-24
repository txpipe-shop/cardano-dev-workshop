use cardano/transaction.{NoDatum, Output, OutputReference, Transaction}
use swap.{AssetClass, OrderDatum}
use mocktail/virgin_key_hash.{mock_policy_id}
use aiken/primitive/bytearray
use mocktail/virgin_address.{mock_pub_key_address}
use cardano/assets.{add, zero}
use mocktail.{add_output, complete, mocktail_tx}
use mocktail/virgin_output_reference.{mock_utxo_ref}
use swap

// Example of unit tests for the swap validator.
type TestCase {
  is_paid_to_destination: Bool,
  is_value_correct: Bool,
}

// Generate mock settings for the swap validator tests.
// This function creates a mock transaction, datum and output reference based on the test case parameters.
fn mock_settings(
  test_case: TestCase,
) -> (OutputReference, OrderDatum, Transaction) {
  let datum = {
    let asset_requested =
      AssetClass {
        policy_id: mock_policy_id(0),
        asset_name: bytearray.from_string(@"HelloWorld"),
      }
    let destination = mock_pub_key_address(0, None)
    OrderDatum { asset_requested, amount_requested: 1000, destination }
  }

  let tx = {
    // Create a mock transaction with the given parameters.
    // The transaction will have a single output that represents the payment for the swap.
    // The output will be created based on the test case parameters.
    let value =
      if test_case.is_value_correct {
        zero
          |> add(
              datum.asset_requested.policy_id,
              datum.asset_requested.asset_name,
              datum.amount_requested,
            )
      } else {
        zero
          |> add(mock_policy_id(1), bytearray.from_string(@"WrongAsset"), 1000)
      }

    // Different address for failure case
    let address =
      if test_case.is_paid_to_destination {
        datum.destination
      } else {
        mock_pub_key_address(1, None)
      }

    let payment_output =
      Output { address, value, datum: NoDatum, reference_script: None }

    mocktail_tx()
      |> complete()
      |> add_output(True, payment_output)
  }

  let output_reference = mock_utxo_ref(0, 1)

  (output_reference, datum, tx)
}

// Everything goes well
test success() {
  let test_case =
    TestCase { is_paid_to_destination: True, is_value_correct: True }
  let (ref, datum, tx) = mock_settings(test_case)

  swap.swap.spend(Some(datum), Void, ref, tx)
}

// The payment value is incorrect
test fail_value() fail {
  let test_case =
    TestCase { is_paid_to_destination: True, is_value_correct: False }
  let (ref, datum, tx) = mock_settings(test_case)

  swap.swap.spend(Some(datum), Void, ref, tx)
}

// The payment is not sent to the correct destination address
test fail_destination() fail {
  let test_case =
    TestCase { is_paid_to_destination: False, is_value_correct: True }
  let (ref, datum, tx) = mock_settings(test_case)

  swap.swap.spend(Some(datum), Void, ref, tx)
}
