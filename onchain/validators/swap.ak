use aiken/primitive/bytearray
use cardano/address.{Address}
use cardano/assets.{add, match, zero}
use cardano/transaction.{NoDatum, Output, OutputReference, Transaction}
use mocktail.{add_output, complete, mocktail_tx}
use mocktail/virgin_address.{mock_pub_key_address}
use mocktail/virgin_key_hash.{mock_policy_id}
use mocktail/virgin_output_reference.{mock_utxo_ref}

pub type AssetClass {
  policy_id: ByteArray,
  asset_name: ByteArray,
}

pub type OrderDatum {
  asset_requested: AssetClass,
  amount_requested: Int,
  // The address that will receive the payment of the swap
  destination: Address,
}

// The Swap validator will be run whenever a Swap order is spent. It checks:
//   1. The value of the swap must be paid to the destination address.
//   2. The value must match the what is described in the order datum.
validator swap {
  // Parameters:
  //   - datum: The datum of the order being spent.
  //   - redeemer: The intent on which the is order being spent.
  //   - own_ref: The reference to the UTxO being spent.
  //   - tx: The information of the transaction which can be used to validate the spending of the order.
  spend(
    datum: Option<OrderDatum>,
    _redeemer: Data,
    _own_ref: OutputReference,
    tx: Transaction,
  ) {
    expect Some(datum) = datum

    // Destructure the datum to get the fields we need. We could do the same for any constructor type.
    let OrderDatum { asset_requested, amount_requested, destination } = datum

    // We know the order of the outputs, so we can just access the index where we want the payment output:
    expect [payment_output, ..] = tx.outputs

    // The datum describes what the expected payment value is.
    let expected_payment_value =
      zero
        |> add(
            asset_requested.policy_id,
            asset_requested.asset_name,
            amount_requested,
          )

    // Now perform the checks:
    and {
      (payment_output.address == destination)?,
      match(payment_output.value, expected_payment_value, >=)?,
    }
  }

  else(_) {
    fail
  }
}

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

  swap.spend(Some(datum), Void, ref, tx)
}

// The payment value is incorrect
test fail_value() fail {
  let test_case =
    TestCase { is_paid_to_destination: True, is_value_correct: False }
  let (ref, datum, tx) = mock_settings(test_case)

  swap.spend(Some(datum), Void, ref, tx)
}

// The payment is not sent to the correct destination address
test fail_destination() fail {
  let test_case =
    TestCase { is_paid_to_destination: False, is_value_correct: True }
  let (ref, datum, tx) = mock_settings(test_case)

  swap.spend(Some(datum), Void, ref, tx)
}
