// Tests for ../firestore.rules. Each "allows" case replays a write exactly as
// the PaddlerBites apps make it; each "blocks" case is something a modified
// app or a curious student could try.
//
//   cd firestore_rules_test && npm install && npm test

import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  addDoc, collection, deleteDoc, deleteField, doc, GeoPoint, getDoc, getDocs, increment, limitToLast,
  orderBy, query, runTransaction, serverTimestamp, setDoc, Timestamp, updateDoc, where, writeBatch,
} from 'firebase/firestore';

let env;

const campus = (uid) => ({ email: `${uid}@csucc.edu.ph`, email_verified: true });
const as = (uid) => env.authenticatedContext(uid, campus(uid)).firestore();
const outsider = () => env.authenticatedContext('outsider', { email: 'someone@gmail.com' }).firestore();

const point = new GeoPoint(9.1172, 125.535);

function order(overrides = {}) {
  return {
    customerId: 'cust1', customerName: 'Cust', stallId: 'vend1', stallName: 'Foody',
    items: [{ itemId: 'item1', name: 'Burger', price: 30, qty: 2 }],
    subtotal: 60, deliveryFee: 15, totalPrice: 75, paymentMethod: 'COD',
    status: 'Pending', deliveryLocation: 'BSIT 204', deliveryPoint: point, pickupPoint: point,
    deliveryPersonId: null, createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
    ...overrides,
  };
}

const user = (overrides) => ({
  name: 'Student', isCustomer: true, customerStatus: 'approved', activeRole: null, schemaVersion: 2,
  ...overrides,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-paddlerbites',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8085 },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const seed = {
      'users/cust1': user({ email: 'cust1@csucc.edu.ph' }),
      'users/vend1': user({ email: 'vend1@csucc.edu.ph', vendorStatus: 'approved', stallId: 'vend1', activeRole: 'vendor' }),
      'users/vend2': user({ email: 'vend2@csucc.edu.ph', vendorStatus: 'approved', stallId: 'vend2' }),
      'users/rider1': user({ email: 'rider1@csucc.edu.ph', deliveryStatus: 'approved', activeRole: 'delivery' }),
      'users/rider2': user({ email: 'rider2@csucc.edu.ph', deliveryStatus: 'approved' }),
      'users/applicant': user({ email: 'applicant@csucc.edu.ph', deliveryStatus: 'pending' }),
      'users/admin1': user({ email: 'admin1@csucc.edu.ph', isAdmin: true }),
      'users/legacy1': { name: 'Old account', email: 'legacy1@csucc.edu.ph', role: 'customer', status: 'Active' },
      'users/cust1/cart/item1': { name: 'Burger', price: 30, qty: 1, stallId: 'vend1' },
      'stalls/vend1': { ownerId: 'vend1', stallName: 'Foody', program: 'BSIT', category: 'Snacks', operatingHours: '7-5',
                        pickupPoint: point, status: 'Active', isOpen: true, rating: 0, totalOrders: 3 },
      'stalls/vend2': { ownerId: 'vend2', stallName: 'Closed Co', program: 'BSIT', category: 'Snacks', operatingHours: '7-5',
                        pickupPoint: point, status: 'Active', isOpen: false, rating: 0, totalOrders: 0 },
      'menuItems/item1': { stallId: 'vend1', stallName: 'Foody', name: 'Burger', description: '', price: 30, category: 'Snacks',
                           isAvailable: true, rating: 0, imageUrl: '', imagePath: '' },
      'orders/pending': order(),
      'orders/preparing': order({ status: 'Preparing' }),
      'orders/ready': order({ status: 'Ready' }),
      'orders/pickedUp': order({ status: 'Picked up', deliveryPersonId: 'rider1', deliveryPersonName: 'Rider One' }),
      'orders/onTheWay': order({ status: 'On the way', deliveryPersonId: 'rider1', deliveryPersonName: 'Rider One' }),
      'orders/delivered': order({ status: 'Delivered', deliveryPersonId: 'rider1', deliveryPersonName: 'Rider One' }),
      'orders/onTheWay/messages/m1': { senderId: 'rider1', senderName: 'Rider One', senderRole: 'rider', text: 'Hi',
                                       sentAt: Timestamp.now(), clientSentAt: Timestamp.now() },
    };
    for (const [path, data] of Object.entries(seed)) await setDoc(doc(db, path), data);
  });
});

// ---------------------------------------------------------------- Accounts

describe('users', () => {
  test('allows: first sign-in creates a customer profile (AuthService.ensureProfile)', async () => {
    const db = as('newbie');
    await assertSucceeds(setDoc(doc(db, 'users/newbie'), {
      name: 'New', email: 'newbie@csucc.edu.ph', isCustomer: true, customerStatus: 'approved', activeRole: null,
      schemaVersion: 2, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(doc(db, 'users/newbie'), { activeRole: null }));
  });

  test('blocks: creating a profile that is already admin or approved', async () => {
    const db = as('newbie');
    const base = { name: 'New', email: 'newbie@csucc.edu.ph', isCustomer: true, customerStatus: 'approved', schemaVersion: 2 };
    await assertFails(setDoc(doc(db, 'users/newbie'), { ...base, isAdmin: true }));
    await assertFails(setDoc(doc(db, 'users/newbie'), { ...base, deliveryStatus: 'approved' }));
    await assertFails(setDoc(doc(db, 'users/someoneelse'), base));
  });

  test('blocks: non-campus accounts entirely', async () => {
    const db = outsider();
    await assertFails(setDoc(doc(db, 'users/outsider'), { name: 'x', email: 'someone@gmail.com' }));
    await assertFails(getDoc(doc(db, 'stalls/vend1')));
  });

  test('blocks: the admin console self-provisioning admin access', async () => {
    await assertFails(setDoc(doc(as('cust1'), 'users/cust1'), { isAdmin: true, email: 'cust1@csucc.edu.ph' }, { merge: true }));
  });

  test('allows: own settings, applying as a rider, switching to an approved module', async () => {
    const db = as('cust1');
    await assertSucceeds(updateDoc(doc(db, 'users/cust1'), { notificationsEnabled: false, name: 'Renamed' }));
    await assertSucceeds(updateDoc(doc(db, 'users/cust1'), {
      name: 'Renamed', studentId: '21-0001', contactNumber: '0917', idImageUrl: 'firestore-image:x', idImagePath: '',
      deliveryStatus: 'pending', deliveryReviewNote: '', deliveryAppliedAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(doc(db, 'users/cust1'), { activeRole: 'customer', isOnline: false }));
    await assertSucceeds(updateDoc(doc(as('vend1'), 'users/vend1'), {
      stallId: 'vend1', vendorStatus: 'pending', vendorReviewNote: '', vendorAppliedAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(doc(as('rider1'), 'users/rider1'), { isOnline: true, deliveryMode: 'Walking' }));
  });

  test('blocks: approving yourself, becoming admin, or opening a module you lack', async () => {
    const db = as('applicant');
    await assertFails(updateDoc(doc(db, 'users/applicant'), { deliveryStatus: 'approved' }));
    await assertFails(updateDoc(doc(db, 'users/applicant'), { isAdmin: true }));
    await assertFails(updateDoc(doc(db, 'users/applicant'), { activeRole: 'delivery' }));
    await assertFails(updateDoc(doc(db, 'users/applicant'), { isOnline: true }));
    await assertFails(updateDoc(doc(db, 'users/applicant'), { deliveryReviewNote: 'Looks great, approved' }));
    await assertFails(updateDoc(doc(as('cust1'), 'users/cust1'), { stallId: 'vend1' }));
  });

  test('allows: the one-time upgrade of a legacy account (AppUser.migrationFor)', async () => {
    await assertSucceeds(updateDoc(doc(as('legacy1'), 'users/legacy1'), {
      isCustomer: true, customerStatus: 'approved', vendorStatus: deleteField(), deliveryStatus: deleteField(),
      role: deleteField(), status: deleteField(), reviewNote: deleteField(), schemaVersion: 2, updatedAt: serverTimestamp(),
    }));
  });

  test('blocks: smuggling a role approval into the legacy upgrade', async () => {
    await assertFails(updateDoc(doc(as('legacy1'), 'users/legacy1'), {
      isCustomer: true, customerStatus: 'approved', vendorStatus: 'approved', schemaVersion: 2,
    }));
  });

  test('profiles are private; admins see and manage everyone', async () => {
    await assertFails(getDoc(doc(as('cust1'), 'users/rider1')));
    await assertFails(getDocs(collection(as('cust1'), 'users')));
    await assertSucceeds(getDocs(collection(as('admin1'), 'users')));
    await assertSucceeds(updateDoc(doc(as('admin1'), 'users/applicant'), {
      deliveryStatus: 'approved', deliveryReviewNote: '', deliveryReviewedAt: serverTimestamp(), deliveryReviewedBy: 'admin1',
    }));
    await assertSucceeds(updateDoc(doc(as('admin1'), 'users/cust1'), { isAdmin: true }));
  });

  test('cart, favourites and recently viewed are private', async () => {
    await assertSucceeds(updateDoc(doc(as('cust1'), 'users/cust1/cart/item1'), { qty: 2 }));
    await assertSucceeds(setDoc(doc(as('cust1'), 'users/cust1/favorites/item1'), { name: 'Burger' }));
    await assertFails(getDocs(collection(as('rider1'), 'users/cust1/cart')));
    await assertFails(setDoc(doc(as('rider1'), 'users/cust1/cart/item9'), { qty: 99 }));
  });
});

// ------------------------------------------------------- Stalls and menus

describe('stalls and menu items', () => {
  const stallInfo = { ownerId: 'newvend', stallName: 'New Stall', program: 'BSEntrep', category: 'Snacks',
                      operatingHours: '7-5', pickupPoint: point, updatedAt: serverTimestamp() };

  test('allows: a vendor submitting their own stall for review (CatalogService.saveStall)', async () => {
    await assertSucceeds(setDoc(doc(as('newvend'), 'stalls/newvend'), {
      ...stallInfo, status: 'Pending Review', isOpen: false, submittedAt: serverTimestamp(),
      rating: 0, totalOrders: 0, createdAt: serverTimestamp(),
    }, { merge: true }));
  });

  test('blocks: approving your own stall or editing someone else\'s', async () => {
    await assertFails(setDoc(doc(as('newvend'), 'stalls/newvend'), { ...stallInfo, status: 'Active', isOpen: true }));
    await assertFails(updateDoc(doc(as('vend1'), 'stalls/vend1'), { status: 'Active', rating: 5 }));
    await assertFails(updateDoc(doc(as('vend1'), 'stalls/vend1'), { totalOrders: 999 }));
    await assertFails(updateDoc(doc(as('vend1'), 'stalls/vend2'), { stallName: 'Mine now' }));
  });

  test('allows: the owner opening, closing and editing an approved stall', async () => {
    const db = as('vend1');
    await assertSucceeds(updateDoc(doc(db, 'stalls/vend1'), { isOpen: false, updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(db, 'stalls/vend1'), { isOpen: true, operatingHours: '8-4', updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(db, 'stalls/vend1'), { payoutAccount: 'GCash 0917', updatedAt: serverTimestamp() }));
  });

  test('stall order counter: riders add exactly one', async () => {
    await assertSucceeds(updateDoc(doc(as('rider1'), 'stalls/vend1'), { totalOrders: increment(1) }));
    await assertFails(updateDoc(doc(as('rider1'), 'stalls/vend1'), { totalOrders: increment(5) }));
    await assertFails(updateDoc(doc(as('cust1'), 'stalls/vend1'), { totalOrders: increment(1) }));
  });

  test('allows: the owner managing their menu (CatalogService.saveMenuItem)', async () => {
    const db = as('vend1');
    const ref = await assertSucceeds(addDoc(collection(db, 'menuItems'), {
      imageUrl: '', imagePath: '', stallId: 'vend1', stallName: 'Foody', name: 'Fries', description: 'Crispy',
      price: 35, category: 'Snacks', isAvailable: true, updatedAt: serverTimestamp(), rating: 0, createdAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(doc(db, 'menuItems/item1'), { price: 32, isAvailable: false, updatedAt: serverTimestamp() }));
    await assertSucceeds(deleteDoc(ref));
  });

  test('blocks: adding to another stall\'s menu, faking ratings, other users editing', async () => {
    const item = { stallId: 'vend1', stallName: 'Foody', name: 'Fake', price: 1, isAvailable: true };
    await assertFails(addDoc(collection(as('vend2'), 'menuItems'), item));
    await assertFails(updateDoc(doc(as('vend1'), 'menuItems/item1'), { rating: 5 }));
    await assertFails(updateDoc(doc(as('cust1'), 'menuItems/item1'), { price: 1 }));
    await assertFails(deleteDoc(doc(as('vend2'), 'menuItems/item1')));
    await assertSucceeds(updateDoc(doc(as('admin1'), 'menuItems/item1'), { isAvailable: false, updatedAt: serverTimestamp() }));
  });

  test('images: only your own uploads', async () => {
    await assertSucceeds(setDoc(doc(as('vend1'), 'images/img1'), { contentType: 'image/jpeg', size: 1000, ownerId: 'vend1', label: 'x' }));
    await assertFails(setDoc(doc(as('vend1'), 'images/img2'), { contentType: 'image/jpeg', size: 1000, ownerId: 'cust1', label: 'x' }));
    await assertFails(deleteDoc(doc(as('cust1'), 'images/img1')));
  });
});

// ------------------------------------------------------------------ Orders

describe('orders', () => {
  test('allows: checkout as one batch with the cart cleared (OrderService.placeOrders)', async () => {
    const db = as('cust1');
    const batch = writeBatch(db);
    batch.set(doc(collection(db, 'orders')), order({ createdAt: serverTimestamp(), updatedAt: serverTimestamp() }));
    batch.delete(doc(db, 'users/cust1/cart/item1'));
    await assertSucceeds(batch.commit());
  });

  test('blocks: orders that skip steps, impersonate, or target a closed stall', async () => {
    const db = as('cust1');
    const now = { createdAt: serverTimestamp(), updatedAt: serverTimestamp() };
    await assertFails(addDoc(collection(db, 'orders'), order({ ...now, status: 'Ready' })));
    await assertFails(addDoc(collection(db, 'orders'), order({ ...now, deliveryPersonId: 'rider1' })));
    await assertFails(addDoc(collection(db, 'orders'), order({ ...now, customerId: 'rider1' })));
    await assertFails(addDoc(collection(db, 'orders'), order({ ...now, stallId: 'vend2' })));
    await assertFails(addDoc(collection(db, 'orders'), order({ ...now, totalPrice: 1 })));
  });

  test('reads: each screen\'s query is allowed, browsing everything is not', async () => {
    await assertSucceeds(getDocs(query(collection(as('cust1'), 'orders'), where('customerId', '==', 'cust1'))));
    await assertSucceeds(getDocs(query(collection(as('vend1'), 'orders'), where('stallId', '==', 'vend1'))));
    await assertSucceeds(getDocs(query(collection(as('rider1'), 'orders'), where('deliveryPersonId', '==', 'rider1'))));
    await assertSucceeds(getDocs(query(collection(as('rider2'), 'orders'), where('status', '==', 'Ready'))));
    await assertSucceeds(getDocs(collection(as('admin1'), 'orders')));

    await assertFails(getDocs(collection(as('cust1'), 'orders')));
    await assertFails(getDocs(query(collection(as('cust1'), 'orders'), where('status', '==', 'Ready'))));
    await assertFails(getDocs(query(collection(as('applicant'), 'orders'), where('status', '==', 'Ready'))));
    await assertFails(getDoc(doc(as('rider2'), 'orders/onTheWay')));
    await assertFails(getDoc(doc(as('vend2'), 'orders/pending')));
  });

  test('customer: cancel only while pending; rate and report delivered orders', async () => {
    const db = as('cust1');
    const cancel = { status: 'Cancelled', updatedAt: serverTimestamp(), cancelledAt: serverTimestamp() };
    await assertSucceeds(updateDoc(doc(db, 'orders/pending'), cancel));
    await assertFails(updateDoc(doc(db, 'orders/preparing'), cancel));
    await assertSucceeds(updateDoc(doc(db, 'orders/delivered'), { customerRating: 5, ratedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(db, 'orders/delivered'), { customerRating: 50 }));
    await assertSucceeds(updateDoc(doc(db, 'orders/delivered'), { issueReport: { message: 'Cold fries', reportedAt: serverTimestamp() } }));
    await assertFails(updateDoc(doc(db, 'orders/pending'), { totalPrice: 1 }));
    await assertFails(updateDoc(doc(db, 'orders/onTheWay'), { status: 'Delivered' }));
  });

  test('stall: accept, decline, mark ready — nothing else', async () => {
    const db = as('vend1');
    await assertSucceeds(updateDoc(doc(db, 'orders/pending'), { status: 'Preparing', updatedAt: serverTimestamp(), acceptedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(db, 'orders/preparing'), { status: 'Ready', updatedAt: serverTimestamp(), readyAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(db, 'orders/ready'), { status: 'Delivered', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(as('vend2'), 'orders/preparing'), { status: 'Ready', updatedAt: serverTimestamp() }));
  });

  test('rider: claim a ready order in a transaction (OrderService.acceptDelivery)', async () => {
    const db = as('rider2');
    await assertSucceeds(runTransaction(db, async (tx) => {
      const ref = doc(db, 'orders/ready');
      await tx.get(ref);
      tx.update(ref, { status: 'Picked up', updatedAt: serverTimestamp(), pickedUpAt: serverTimestamp(),
                       deliveryPersonId: 'rider2', deliveryPersonName: 'Rider Two' });
    }));
  });

  test('blocks: claiming for someone else, stealing a claimed order, unapproved riders', async () => {
    const claim = (by) => ({ status: 'Picked up', updatedAt: serverTimestamp(), deliveryPersonId: by, deliveryPersonName: 'X' });
    await assertFails(updateDoc(doc(as('rider2'), 'orders/ready'), claim('rider1')));
    await assertFails(updateDoc(doc(as('applicant'), 'orders/ready'), claim('applicant')));
    await assertFails(updateDoc(doc(as('rider2'), 'orders/pickedUp'), { deliveryPersonId: 'rider2' }));
  });

  test('rider: deliver step by step, share GPS, count the delivery', async () => {
    const db = as('rider1');
    await assertSucceeds(updateDoc(doc(db, 'orders/pickedUp'), { status: 'On the way', updatedAt: serverTimestamp(), departedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(db, 'orders/onTheWay'), { riderLocation: point, riderLocationUpdatedAt: serverTimestamp() }));
    await assertSucceeds(runTransaction(db, async (tx) => {
      const ref = doc(db, 'orders/onTheWay');
      await tx.get(ref);
      tx.update(ref, { status: 'Delivered', updatedAt: serverTimestamp(), deliveredAt: serverTimestamp() });
      tx.update(doc(db, 'stalls/vend1'), { totalOrders: increment(1) });
    }));
    await assertFails(updateDoc(doc(db, 'orders/delivered'), { riderLocation: point }));
    await assertFails(updateDoc(doc(as('rider2'), 'orders/pickedUp'), { riderLocation: point }));
    await assertFails(updateDoc(doc(db, 'orders/pickedUp'), { totalPrice: 0 }));
  });

  test('admin: cancel any active order', async () => {
    await assertSucceeds(updateDoc(doc(as('admin1'), 'orders/onTheWay'), {
      status: 'Cancelled', cancelledAt: serverTimestamp(), updatedAt: serverTimestamp(), cancelledBy: 'admin', cancelReason: 'Test',
    }));
    await assertFails(deleteDoc(doc(as('admin1'), 'orders/onTheWay')));
  });
});

// -------------------------------------------------------------------- Chat

describe('order chat', () => {
  const message = (senderId, senderRole, text = 'On my way!') => ({
    senderId, senderName: 'Name', senderRole, text, sentAt: serverTimestamp(), clientSentAt: Timestamp.now(),
  });

  test('allows: the customer and the rider of the order (ChatService)', async () => {
    await assertSucceeds(addDoc(collection(as('cust1'), 'orders/onTheWay/messages'), message('cust1', 'customer')));
    await assertSucceeds(addDoc(collection(as('rider1'), 'orders/onTheWay/messages'), message('rider1', 'rider')));
    await assertSucceeds(getDocs(query(collection(as('cust1'), 'orders/onTheWay/messages'), orderBy('sentAt'), limitToLast(200))));
    await assertSucceeds(getDocs(collection(as('admin1'), 'orders/onTheWay/messages')));
  });

  test('blocks: outsiders, spoofed senders, closed chats, edits', async () => {
    await assertFails(getDocs(collection(as('rider2'), 'orders/onTheWay/messages')));
    await assertFails(getDocs(collection(as('vend1'), 'orders/onTheWay/messages')));
    await assertFails(addDoc(collection(as('rider2'), 'orders/onTheWay/messages'), message('rider2', 'rider')));
    await assertFails(addDoc(collection(as('cust1'), 'orders/onTheWay/messages'), message('rider1', 'rider')));
    await assertFails(addDoc(collection(as('cust1'), 'orders/onTheWay/messages'), message('cust1', 'rider')));
    await assertFails(addDoc(collection(as('cust1'), 'orders/onTheWay/messages'), message('cust1', 'customer', 'x'.repeat(501))));
    await assertFails(addDoc(collection(as('cust1'), 'orders/delivered/messages'), message('cust1', 'customer')));
    await assertFails(addDoc(collection(as('cust1'), 'orders/pending/messages'), message('cust1', 'customer')));
    await assertFails(updateDoc(doc(as('rider1'), 'orders/onTheWay/messages/m1'), { text: 'edited' }));
    await assertFails(deleteDoc(doc(as('rider1'), 'orders/onTheWay/messages/m1')));
  });
});
