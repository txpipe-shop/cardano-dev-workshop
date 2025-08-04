use aiken/builtin.{slice_bytearray}
use cardano/assets.{add, match, zero}
use cardano/transaction.{Output, OutputReference, Transaction}
use vodka_address.{address_payment_key}

pub type OrderDatum {
  asset_requested_policy: ByteArray,
  asset_requested_name: ByteArray,
  amount_requested: Int,
  // The payment key of the address that will receive the payout of the swap
  destination: ByteArray,
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
    let OrderDatum {
      asset_requested_policy,
      asset_requested_name,
      amount_requested,
      destination,
    } = datum

    let recipient_payment_key = slice_bytearray(0, 28, destination)

    // We know the order of the outputs, so we can just access the index where we want the payment output:
    expect [payment_output, ..] = tx.outputs

    // The datum describes what the expected payment value is.
    let expected_payment_value =
      zero
        |> add(asset_requested_policy, asset_requested_name, amount_requested)
    let expected_destination_key = address_payment_key(payment_output.address)

    // Now perform the checks:
    and {
      (expected_destination_key == recipient_payment_key)?,
      match(payment_output.value, expected_payment_value, >=)?,
    }
  }

  else(_) {
    fail
  }
}
