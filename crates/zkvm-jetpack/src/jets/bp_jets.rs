use nockvm::interpreter::Context;
use nockvm::jets::util::slot;
use nockvm::jets::Result;
use nockvm::noun::{Atom, IndirectAtom, Noun, D, T};

use crate::form::math::bpoly::*;
use crate::form::poly::*;
use crate::hand::handle::*;
use crate::hand::structs::HoonList;
use crate::jets::utils::jet_err;
use crate::noun::noun_ext::{AtomExt, NounExt};

pub fn bpoly_to_list_jet(context: &mut Context, subject: Noun) -> Result {
    let sam = slot(subject, 6)?;
    bpoly_to_list(context, sam)
}

pub fn bpoly_to_list(context: &mut Context, sam: Noun) -> Result {
    let Ok(sam_bpoly) = BPolySlice::try_from(sam) else {
        return jet_err();
    };

    //  empty list is a null atom
    let mut res_list = D(0);

    let len = sam_bpoly.len();

    if len == 0 {
        return Ok(res_list);
    }

    for i in (0..len).rev() {
        let res_atom = Atom::new(&mut context.stack, sam_bpoly.0[i].into());
        res_list = T(&mut context.stack, &[res_atom.as_noun(), res_list]);
    }

    Ok(res_list)
}

pub fn bpadd_jet(context: &mut Context, subject: Noun) -> Result {
    let sam = slot(subject, 6)?;
    let bp = slot(sam, 2)?;
    let bq = slot(sam, 3)?;

    let (Ok(bp_poly), Ok(bq_poly)) = (BPolySlice::try_from(bp), BPolySlice::try_from(bq)) else {
        return jet_err();
    };

    let res_len = std::cmp::max(bp_poly.len(), bq_poly.len());
    let (res, res_poly): (IndirectAtom, &mut [Belt]) =
        new_handle_mut_slice(&mut context.stack, Some(res_len as usize));
    bpadd(bp_poly.0, bq_poly.0, res_poly);

    let res_cell = finalize_poly(&mut context.stack, Some(res_poly.len()), res);

    Ok(res_cell)
}

pub fn bpneg_jet(context: &mut Context, subject: Noun) -> Result {
    let bp = slot(subject, 6)?;

    let Ok(bp_poly) = BPolySlice::try_from(bp) else {
        return jet_err();
    };

    let (res, res_poly): (IndirectAtom, &mut [Belt]) =
        new_handle_mut_slice(&mut context.stack, Some(bp_poly.len()));
    bpneg(bp_poly.0, res_poly);

    let res_cell = finalize_poly(&mut context.stack, Some(res_poly.len()), res);

    Ok(res_cell)
}

pub fn bpsub_jet(context: &mut Context, subject: Noun) -> Result {
    let sam = slot(subject, 6)?;
    let p = slot(sam, 2)?;
    let q = slot(sam, 3)?;

    let (Ok(p_poly), Ok(q_poly)) = (BPolySlice::try_from(p), BPolySlice::try_from(q)) else {
        return jet_err();
    };

    let res_len = std::cmp::max(p_poly.len(), q_poly.len());
    let (res, res_poly): (IndirectAtom, &mut [Belt]) =
        new_handle_mut_slice(&mut context.stack, Some(res_len as usize));
    bpsub(p_poly.0, q_poly.0, res_poly);

    let res_cell = finalize_poly(&mut context.stack, Some(res_poly.len()), res);

    Ok(res_cell)
}

pub fn bpscal_jet(context: &mut Context, subject: Noun) -> Result {
    let sam = slot(subject, 6)?;
    let c = slot(sam, 2)?;
    let bp = slot(sam, 3)?;
    let (Ok(c_atom), Ok(bp_poly)) = (c.as_atom(), BPolySlice::try_from(bp)) else {
        return jet_err();
    };
    let c_64 = c_atom.as_u64()?;

    let (res, res_poly): (IndirectAtom, &mut [Belt]) =
        new_handle_mut_slice(&mut context.stack, Some(bp_poly.len()));
    bpscal(Belt(c_64), bp_poly.0, res_poly);

    let res_cell = finalize_poly(&mut context.stack, Some(res_poly.len()), res);

    Ok(res_cell)
}

pub fn bpmul_jet(context: &mut Context, subject: Noun) -> Result {
    let sam = slot(subject, 6)?;
    let bp = slot(sam, 2)?;
    let bq = slot(sam, 3)?;

    let (Ok(bp_poly), Ok(bq_poly)) = (BPolySlice::try_from(bp), BPolySlice::try_from(bq)) else {
        return jet_err();
    };

    let res_len = if bp_poly.is_zero() | bq_poly.is_zero() {
        1
    } else {
        bp_poly.len() + bq_poly.len() - 1
    };

    let (res_atom, res_poly): (IndirectAtom, &mut [Belt]) =
        new_handle_mut_slice(&mut context.stack, Some(res_len));

    bpmul(bp_poly.0, bq_poly.0, res_poly);
    let res_cell = finalize_poly(&mut context.stack, Some(res_len), res_atom);

    Ok(res_cell)
}

pub fn bp_hadamard_jet(context: &mut Context, subject: Noun) -> Result {
    let sam = slot(subject, 6)?;
    let bp = slot(sam, 2)?;
    let bq = slot(sam, 3)?;

    let (Ok(bp_poly), Ok(bq_poly)) = (BPolySlice::try_from(bp), BPolySlice::try_from(bq)) else {
        return jet_err();
    };
    assert_eq!(bp_poly.len(), bq_poly.len());
    let res_len = bp_poly.len();
    let (res, res_poly): (IndirectAtom, &mut [Belt]) =
        new_handle_mut_slice(&mut context.stack, Some(res_len));
    bp_hadamard(bp_poly.0, bq_poly.0, res_poly);

    let res_cell = finalize_poly(&mut context.stack, Some(res_poly.len()), res);

    Ok(res_cell)
}

pub fn bp_ntt_jet(context: &mut Context, subject: Noun) -> Result {
    let sam = slot(subject, 6)?;
    let bp = slot(sam, 2)?;
    let root = slot(sam, 3)?;

    let (Ok(bp_poly), Ok(root_atom)) = (BPolySlice::try_from(bp), root.as_atom()) else {
        return jet_err();
    };
    let root_64 = root_atom.as_u64()?;
    let returned_bpoly = bp_ntt(bp_poly.0, &Belt(root_64));
    // TODO: preallocate and pass res buffer into bp_ntt?
    let (res_atom, res_poly): (IndirectAtom, &mut [Belt]) =
        new_handle_mut_slice(&mut context.stack, Some(returned_bpoly.len() as usize));
    res_poly.copy_from_slice(&returned_bpoly[..]);

    let res_cell: Noun = finalize_poly(&mut context.stack, Some(res_poly.len()), res_atom);

    Ok(res_cell)
}

pub fn bp_fft_jet(context: &mut Context, subject: Noun) -> Result {
    let p = slot(subject, 6)?;

    let Ok(p_poly) = BPolySlice::try_from(p) else {
        return jet_err();
    };
    let returned_bpoly = bp_fft(p_poly.0)?;
    let (res_atom, res_poly): (IndirectAtom, &mut [Belt]) =
        new_handle_mut_slice(&mut context.stack, Some(returned_bpoly.len() as usize));

    res_poly.copy_from_slice(&returned_bpoly);

    let res_cell: Noun = finalize_poly(&mut context.stack, Some(res_poly.len()), res_atom);

    Ok(res_cell)
}

pub fn bp_shift_jet(context: &mut Context, subject: Noun) -> Result {
    let sam = slot(subject, 6)?;
    let bp = slot(sam, 2)?;
    let c = slot(sam, 3)?;

    let (Ok(bp_poly), Ok(c_belt)) = (BPolySlice::try_from(bp), c.as_belt()) else {
        return jet_err();
    };
    let (res_atom, res_poly): (IndirectAtom, &mut [Belt]) =
        new_handle_mut_slice(&mut context.stack, Some(bp_poly.len()));
    bp_shift(bp_poly.0, &c_belt, res_poly);

    let res_cell = finalize_poly(&mut context.stack, Some(res_poly.len()), res_atom);

    Ok(res_cell)
}

pub fn bp_coseword_jet(context: &mut Context, subject: Noun) -> Result {
    let sam = slot(subject, 6)?;
    let p = slot(sam, 2)?;
    let offset = slot(sam, 6)?;
    let order = slot(sam, 7)?;

    let (Ok(p_poly), Ok(offset_belt), Ok(order_atom)) =
        (BPolySlice::try_from(p), offset.as_belt(), order.as_atom())
    else {
        return jet_err();
    };
    let order_32: u32 = order_atom.as_u32()?;
    let root = Belt(order_32 as u64).ordered_root()?;
    let returned_bpoly = bp_coseword(p_poly.0, &offset_belt, order_32, &root);
    let (res, res_poly): (IndirectAtom, &mut [Belt]) =
        new_handle_mut_slice(&mut context.stack, Some(returned_bpoly.len() as usize));
    res_poly.copy_from_slice(&returned_bpoly);
    let res_cell = finalize_poly(&mut context.stack, Some(res_poly.len()), res);

    Ok(res_cell)
}

pub fn init_bpoly_jet(context: &mut Context, subject: Noun) -> Result {
    let poly = slot(subject, 6)?;

    let list_belt = HoonList::try_from(poly)?.into_iter();
    let count = list_belt.count();
    let (res, res_poly): (IndirectAtom, &mut [Belt]) =
        new_handle_mut_slice(&mut context.stack, Some(count as usize));
    for (i, belt_noun) in list_belt.enumerate() {
        let Ok(belt) = belt_noun.as_belt() else {
            return jet_err();
        };
        res_poly[i] = belt;
    }

    let res_cell = finalize_poly(&mut context.stack, Some(res_poly.len()), res);

    Ok(res_cell)
}
