use aztec::{
    context::{PrivateContext, UtilityContext},
    note::{
        note_emission::OuterNoteEmission,
        note_getter_options::{NoteGetterOptions, SortOrder},
        note_interface::NoteProperties,
        note_viewer_options::NoteViewerOptions,
        retrieved_note::RetrievedNote,
    },
    protocol_types::{address::AztecAddress, constants::MAX_NOTE_HASH_READ_REQUESTS_PER_CALL},
    state_vars::{PrivateSet, storage::HasStorageSlot},
};
use std::ops::Add;
use uint_note::uint_note::UintNote;


/****************************************
 *   @notice - Set of Wallets (balance)   *
 ****************************************/
pub struct WalletSet<Context> {
    pub balance: PrivateSet<UintNote, Context>,
}

impl<Context> WalletSet<Context> {
    pub fn new(context: Context, storage_slot: Field) -> Self {
        assert(storage_slot != 0, "Storage slot 0 not allowed. Storage slots must start from 1.");
        Self { balance: PrivateSet::new(context, storage_slot) }
    }
}

impl WalletSet<&mut PrivateContext> {
    pub fn add(self: Self, owner: AztecAddress, addend: u128) -> OuterNoteEmission<UintNote> {
        let content = if addend == 0 as u128 {
            Option::none()
        } else {
            // We fetch the nullifier public key hash from the registry / from our PXE
            let mut addend_note = UintNote::new(addend, owner);

            Option::some(self.balance.insert(addend_note).content)
        };

        OuterNoteEmission::new(content, self.balance.context)
    }

    pub fn sub(self: Self, owner: AztecAddress, amount: u128) -> OuterNoteEmission<UintNote> {
        let subtracted = self.try_sub(amount, MAX_NOTE_HASH_READ_REQUESTS_PER_CALL);

        // try_sub may have subtracted more or less than amount. We must ensure that we subtracted at least as much as
        // we needed, and then create a new note for the owner for the change (if any).
        assert(subtracted >= amount, "Balance too low");
        self.add(owner, subtracted - amount)
    }

    // Attempts to remove 'target_amount' from the owner's balance. try_sub returns how much was actually subtracted
    // (i.e. the sum of the value of nullified notes), but this subtracted amount may be more or less than the target
    // amount.
    // This may seem odd, but is unfortunately unavoidable due to the number of notes available and their amounts being
    // unknown. What try_sub does is a best-effort attempt to consume as few notes as possible that add up to more than
    // `target_amount`.
    // The `max_notes` parameter is used to fine-tune the number of constraints created by this function. The gate count
    // scales relatively linearly with `max_notes`, but a lower `max_notes` parameter increases the likelihood of
    // `try_sub` subtracting an amount smaller than `target_amount`.
    pub fn try_sub(self: Self, target_amount: u128, max_notes: u32) -> u128 {
        // We are using a preprocessor here (filter applied in an unconstrained context) instead of a filter because
        // we do not need to prove correct execution of the preprocessor.
        // Because the `min_sum` notes is not constrained, users could choose to e.g. not call it. However, all this
        // might result in is simply higher DA costs due to more nullifiers being emitted. Since we don't care
        // about proving optimal note usage, we can save these constraints and make the circuit smaller.
        let options = NoteGetterOptions::with_preprocessor(preprocess_notes_min_sum, target_amount)
            .sort(UintNote::properties().value, SortOrder.DESC)
            .set_limit(max_notes);
        let notes = self.set.pop_notes(options);

        let mut subtracted = 0 as u128;
        for i in 0..options.limit {
            if i < notes.len() {
                let note = notes.get_unchecked(i);
                subtracted = subtracted + note.get_value();
            }
        }

        subtracted
    }
}