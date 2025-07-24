use cardano/address.{Address}
use cardano/assets.{add, match, zero}
use cardano/transaction.{Output, OutputReference, Transaction}


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
