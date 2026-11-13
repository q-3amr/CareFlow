/**
 * Firestore Security Rules Unit Tests
 * 
 * Tests cover:
 * 1. Patient can't read others' appointments
 * 2. Guest reads doctors/booked_slots/reviews
 * 3. Doctor can't set own isVerified
 * 4. Review write limited to owning patient/doctor
 * 
 * Run with: npm test (requires Node.js)
 */

const {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');

const fs = require('fs');
const path = require('path');

// Load the rules file
const rules = fs.readFileSync(path.join(__dirname, 'firestore.rules'), 'utf8');

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'careflow-test',
    firestore: {
      rules,
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

describe('User document rules', () => {
  test('Patient can read their own user document', async () => {
    const db = testEnv.authenticatedContext('patient1').firestore();
    await assertSucceeds(db.doc('users/patient1').get());
  });

  test('Patient can read another patient\'s user document (signed-in users can read all users)', async () => {
    const db = testEnv.authenticatedContext('patient1').firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('users/patient2').set({
        role: 'patient',
        name: 'Patient Two',
      });
    });
    await assertSucceeds(db.doc('users/patient2').get());
  });

  test('Guest can read verified doctor profiles', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('users/doctor1').set({
        role: 'doctor',
        isVerified: true,
        name: 'Dr. Test',
      });
    });
    await assertSucceeds(db.doc('users/doctor1').get());
  });

  test('Guest cannot read unverified doctor profiles', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('users/doctor2').set({
        role: 'doctor',
        isVerified: false,
        name: 'Dr. Unverified',
      });
    });
    await assertFails(db.doc('users/doctor2').get());
  });

  test('Doctor cannot set own isVerified to true', async () => {
    const db = testEnv.authenticatedContext('doctor1').firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('users/doctor1').set({
        role: 'doctor',
        isVerified: false,
        name: 'Dr. Test',
      });
    });
    // Try to update isVerified to true - should fail
    await assertFails(db.doc('users/doctor1').update({ isVerified: true }));
    
    // But doctor should be able to update other fields
    await assertSucceeds(db.doc('users/doctor1').update({ name: 'Dr. Updated' }));
  });

  test('Admin can update any user', async () => {
    const adminDb = testEnv.authenticatedContext('admin1').firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('users/admin1').set({
        role: 'admin',
        name: 'Admin',
      });
      await context.firestore().doc('users/patient1').set({
        role: 'patient',
        name: 'Patient',
      });
    });
    await assertSucceeds(adminDb.doc('users/patient1').update({ name: 'Updated by Admin' }));
  });
});

describe('Appointment rules', () => {
  test('Patient can read their own appointment', async () => {
    const db = testEnv.authenticatedContext('patient1').firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('appointments/appt1').set({
        patient_id: 'patient1',
        doctor_id: 'doctor1',
        status: 'confirmed',
      });
    });
    await assertSucceeds(db.doc('appointments/appt1').get());
  });

  test('Patient cannot read another patient\'s appointment', async () => {
    const db = testEnv.authenticatedContext('patient1').firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('appointments/appt2').set({
        patient_id: 'patient2',
        doctor_id: 'doctor1',
        status: 'confirmed',
      });
    });
    await assertFails(db.doc('appointments/appt2').get());
  });

  test('Doctor can read their own appointments', async () => {
    const db = testEnv.authenticatedContext('doctor1').firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('appointments/appt3').set({
        patient_id: 'patient1',
        doctor_id: 'doctor1',
        status: 'confirmed',
      });
    });
    await assertSucceeds(db.doc('appointments/appt3').get());
  });

  test('Patient can create appointment for themselves', async () => {
    const db = testEnv.authenticatedContext('patient1').firestore();
    await assertSucceeds(db.doc('appointments/newAppt').set({
      patient_id: 'patient1',
      doctor_id: 'doctor1',
      status: 'pending',
    }));
  });

  test('Patient cannot create appointment for another patient', async () => {
    const db = testEnv.authenticatedContext('patient1').firestore();
    await assertFails(db.doc('appointments/newAppt').set({
      patient_id: 'patient2',
      doctor_id: 'doctor1',
      status: 'pending',
    }));
  });

  test('Doctor can update their own appointment status', async () => {
    const db = testEnv.authenticatedContext('doctor1').firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('appointments/appt4').set({
        patient_id: 'patient1',
        doctor_id: 'doctor1',
        status: 'pending',
      });
    });
    await assertSucceeds(db.doc('appointments/appt4').update({ status: 'accepted' }));
  });

  test('Patient can delete their own appointment', async () => {
    const db = testEnv.authenticatedContext('patient1').firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('appointments/appt5').set({
        patient_id: 'patient1',
        doctor_id: 'doctor1',
        status: 'confirmed',
      });
    });
    await assertSucceeds(db.doc('appointments/appt5').delete());
  });
});

describe('Review rules', () => {
  test('Anyone can read reviews (public)', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('reviews/review1').set({
        patient_id: 'patient1',
        doctor_id: 'doctor1',
        rating: 5,
        feedback_text: 'Great!',
      });
    });
    await assertSucceeds(db.doc('reviews/review1').get());
  });

  test('Patient can create review for their own appointment', async () => {
    const db = testEnv.authenticatedContext('patient1').firestore();
    await assertSucceeds(db.doc('reviews/review2').set({
      patient_id: 'patient1',
      doctor_id: 'doctor1',
      rating: 5,
      feedback_text: 'Great!',
    }));
  });

  test('Patient cannot create review for another patient', async () => {
    const db = testEnv.authenticatedContext('patient1').firestore();
    await assertFails(db.doc('reviews/review3').set({
      patient_id: 'patient2',
      doctor_id: 'doctor1',
      rating: 5,
      feedback_text: 'Great!',
    }));
  });

  test('Patient can update their own review', async () => {
    const db = testEnv.authenticatedContext('patient1').firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('reviews/review4').set({
        patient_id: 'patient1',
        doctor_id: 'doctor1',
        rating: 4,
        feedback_text: 'Good',
      });
    });
    await assertSucceeds(db.doc('reviews/review4').update({ rating: 5, feedback_text: 'Excellent!' }));
  });

  test('Doctor can update review for their appointment', async () => {
    const db = testEnv.authenticatedContext('doctor1').firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('reviews/review5').set({
        patient_id: 'patient1',
        doctor_id: 'doctor1',
        rating: 3,
        feedback_text: 'Okay',
      });
    });
    await assertSucceeds(db.doc('reviews/review5').update({ isReviewSeen: true }));
  });

  test('Admin can delete any review', async () => {
    const adminDb = testEnv.authenticatedContext('admin1').firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('users/admin1').set({ role: 'admin' });
      await context.firestore().doc('reviews/review6').set({
        patient_id: 'patient1',
        doctor_id: 'doctor1',
        rating: 1,
        feedback_text: 'Bad',
      });
    });
    await assertSucceeds(adminDb.doc('reviews/review6').delete());
  });
});

describe('Booked slots rules', () => {
  test('Anyone can read booked slots (public for slot checking)', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('booked_slots/slot1').set({
        bookedBy: 'patient1',
        doctorId: 'doctor1',
      });
    });
    await assertSucceeds(db.doc('booked_slots/slot1').get());
  });

  test('Patient can create booked slot for themselves', async () => {
    const db = testEnv.authenticatedContext('patient1').firestore();
    await assertSucceeds(db.doc('booked_slots/newSlot').set({
      bookedBy: 'patient1',
      doctorId: 'doctor1',
    }));
  });

  test('Patient cannot create booked slot for another patient', async () => {
    const db = testEnv.authenticatedContext('patient1').firestore();
    await assertFails(db.doc('booked_slots/newSlot').set({
      bookedBy: 'patient2',
      doctorId: 'doctor1',
    }));
  });

  test('Patient can delete their own booked slot', async () => {
    const db = testEnv.authenticatedContext('patient1').firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('booked_slots/slot2').set({
        bookedBy: 'patient1',
        doctorId: 'doctor1',
      });
    });
    await assertSucceeds(db.doc('booked_slots/slot2').delete());
  });

  test('Doctor can delete booked slot for their appointment', async () => {
    const db = testEnv.authenticatedContext('doctor1').firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('booked_slots/slot3').set({
        bookedBy: 'patient1',
        doctorId: 'doctor1',
      });
    });
    await assertSucceeds(db.doc('booked_slots/slot3').delete());
  });

  test('Booked slots cannot be updated (only create/delete)', async () => {
    const db = testEnv.authenticatedContext('patient1').firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('booked_slots/slot4').set({
        bookedBy: 'patient1',
        doctorId: 'doctor1',
      });
    });
    await assertFails(db.doc('booked_slots/slot4').update({ bookedBy: 'patient2' }));
  });
});

describe('Chat rules', () => {
  test('Participant can read their chat', async () => {
    const db = testEnv.authenticatedContext('patient1').firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('chats/chat1').set({
        participants: ['patient1', 'doctor1'],
      });
    });
    await assertSucceeds(db.doc('chats/chat1').get());
  });

  test('Non-participant cannot read chat', async () => {
    const db = testEnv.authenticatedContext('patient2').firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('chats/chat2').set({
        participants: ['patient1', 'doctor1'],
      });
    });
    await assertFails(db.doc('chats/chat2').get());
  });

  test('Participant can create message in their chat', async () => {
    const db = testEnv.authenticatedContext('patient1').firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('chats/chat3').set({
        participants: ['patient1', 'doctor1'],
      });
    });
    await assertSucceeds(db.collection('chats/chat3/messages').doc('msg1').set({
      senderId: 'patient1',
      text: 'Hello',
      createdAt: new Date(),
    }));
  });
});

describe('Availability rules', () => {
  test('Guest can read verified doctor availability', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('users/doctor1').set({
        role: 'doctor',
        isVerified: true,
      });
      await context.firestore().doc('users/doctor1/availability/2024-01-15').set({
        slots: ['09:00', '10:00'],
      });
    });
    await assertSucceeds(db.doc('users/doctor1/availability/2024-01-15').get());
  });

  test('Guest cannot read unverified doctor availability', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('users/doctor2').set({
        role: 'doctor',
        isVerified: false,
      });
      await context.firestore().doc('users/doctor2/availability/2024-01-15').set({
        slots: ['09:00', '10:00'],
      });
    });
    await assertFails(db.doc('users/doctor2/availability/2024-01-15').get());
  });
});

describe('Default deny', () => {
  test('Unknown collections are denied', async () => {
    const db = testEnv.authenticatedContext('patient1').firestore();
    await assertFails(db.doc('unknown/collection').get());
    await assertFails(db.doc('unknown/collection').set({}));
  });
});