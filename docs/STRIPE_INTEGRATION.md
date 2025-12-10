# Stripe Payment Integration Architecture

## Section 5: Integration Task — Stripe Checkout Implementation

### Overview

This document outlines the complete implementation strategy for integrating Stripe Checkout to handle application fee payments in the LearnLynk CRM system.

---

## Implementation Flow

### 1. **Payment Request Initialization**

When a user decides to pay the application fee, the frontend initiates a payment request:

```typescript
// Frontend: Initiate payment
async function initiatePayment(applicationId: string, amount: number) {
  const { data, error } = await supabase
    .from('payment_requests')
    .insert({
      application_id: applicationId,
      amount: amount,
      status: 'pending',
      tenant_id: user.tenant_id,
      created_by: user.id
    })
    .select()
    .single();
  
  return data;
}
```

**Database Table: `payment_requests`**
```sql
CREATE TABLE payment_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id UUID REFERENCES applications(id),
  tenant_id UUID NOT NULL,
  amount DECIMAL(10, 2) NOT NULL,
  status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'paid', 'failed', 'refunded'
  stripe_session_id VARCHAR(255),
  stripe_payment_intent_id VARCHAR(255),
  created_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

### 2. **Create Stripe Checkout Session**

After creating the payment request, call a backend API endpoint to create a Stripe Checkout session:

```typescript
// Backend API: /api/create-checkout-session
import Stripe from 'stripe';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);

export async function POST(req: Request) {
  const { payment_request_id, application_id, amount } = await req.json();
  
  // Create Stripe Checkout session
  const session = await stripe.checkout.sessions.create({
    payment_method_types: ['card'],
    line_items: [{
      price_data: {
        currency: 'usd',
        product_data: {
          name: 'Application Fee',
          description: `Application ${application_id}`,
        },
        unit_amount: Math.round(amount * 100), // Convert to cents
      },
      quantity: 1,
    }],
    mode: 'payment',
    success_url: `${process.env.NEXT_PUBLIC_APP_URL}/dashboard/payment-success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${process.env.NEXT_PUBLIC_APP_URL}/dashboard/applications/${application_id}`,
    metadata: {
      payment_request_id: payment_request_id,
      application_id: application_id,
    },
  });
  
  // Store session ID in database
  await supabase
    .from('payment_requests')
    .update({ stripe_session_id: session.id })
    .eq('id', payment_request_id);
  
  return Response.json({ url: session.url });
}
```

---

### 3. **Redirect User to Stripe**

The frontend receives the checkout URL and redirects the user:

```typescript
// Frontend: Redirect to Stripe
const response = await fetch('/api/create-checkout-session', {
  method: 'POST',
  body: JSON.stringify({
    payment_request_id: paymentRequest.id,
    application_id: applicationId,
    amount: 500.00
  })
});

const { url } = await response.json();
window.location.href = url; // Redirect to Stripe Checkout
```

---

### 4. **Webhook Handler: Process Payment Completion**

Stripe sends a webhook event when payment is completed. Set up a webhook endpoint to listen for `checkout.session.completed`:

```typescript
// Backend API: /api/webhooks/stripe
import Stripe from 'stripe';
import { headers } from 'next/headers';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);
const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET!;

export async function POST(req: Request) {
  const body = await req.text();
  const signature = headers().get('stripe-signature')!;
  
  let event: Stripe.Event;
  
  try {
    // Verify webhook signature for security
    event = stripe.webhooks.constructEvent(body, signature, webhookSecret);
  } catch (err) {
    console.error('Webhook signature verification failed:', err);
    return Response.json({ error: 'Invalid signature' }, { status: 400 });
  }
  
  // Handle the event
  if (event.type === 'checkout.session.completed') {
    const session = event.data.object as Stripe.Checkout.Session;
    
    // Extract metadata
    const payment_request_id = session.metadata?.payment_request_id;
    const application_id = session.metadata?.application_id;
    
    if (!payment_request_id || !application_id) {
      console.error('Missing metadata in webhook');
      return Response.json({ error: 'Missing metadata' }, { status: 400 });
    }
    
    // Process payment (idempotent)
    await processPayment(
      payment_request_id,
      application_id,
      session.id,
      session.payment_intent as string
    );
  }
  
  return Response.json({ received: true });
}
```

---

### 5. **Process Payment Function (Idempotent)**

The payment processing must be idempotent to handle duplicate webhook deliveries:

```typescript
async function processPayment(
  paymentRequestId: string,
  applicationId: string,
  sessionId: string,
  paymentIntentId: string
) {
  // Use a transaction to ensure atomicity
  const { data: paymentRequest, error } = await supabase
    .from('payment_requests')
    .select('status')
    .eq('id', paymentRequestId)
    .single();
  
  // Check if already processed (idempotency)
  if (paymentRequest?.status === 'paid') {
    console.log('Payment already processed, skipping');
    return;
  }
  
  // Start transaction
  await supabase.rpc('process_payment_transaction', {
    p_payment_request_id: paymentRequestId,
    p_application_id: applicationId,
    p_session_id: sessionId,
    p_payment_intent_id: paymentIntentId
  });
}
```

**Database Function for Transaction:**

```sql
CREATE OR REPLACE FUNCTION process_payment_transaction(
  p_payment_request_id UUID,
  p_application_id UUID,
  p_session_id VARCHAR,
  p_payment_intent_id VARCHAR
) RETURNS VOID AS $$
BEGIN
  -- Update payment request status
  UPDATE payment_requests
  SET 
    status = 'paid',
    stripe_payment_intent_id = p_payment_intent_id,
    updated_at = NOW()
  WHERE id = p_payment_request_id
    AND status = 'pending'; -- Ensure idempotency
  
  -- Update application payment status
  UPDATE applications
  SET 
    payment_status = 'paid',
    status = CASE 
      WHEN status = 'draft' THEN 'submitted'
      ELSE status
    END,
    updated_at = NOW()
  WHERE id = p_application_id;
  
  -- Create audit log entry
  INSERT INTO payment_audit_log (
    payment_request_id,
    application_id,
    event_type,
    stripe_session_id,
    stripe_payment_intent_id,
    created_at
  ) VALUES (
    p_payment_request_id,
    p_application_id,
    'payment_completed',
    p_session_id,
    p_payment_intent_id,
    NOW()
  );
END;
$$ LANGUAGE plpgsql;
```

---

### 6. **Update Application Stage/Timeline**

After payment is confirmed, update the application workflow:

```typescript
// Automatically trigger next steps in the workflow
async function advanceApplicationWorkflow(applicationId: string) {
  // Update application stage
  await supabase
    .from('applications')
    .update({
      status: 'submitted',
      submitted_at: new Date().toISOString()
    })
    .eq('id', applicationId);
  
  // Create follow-up task for counselor
  await supabase
    .from('tasks')
    .insert({
      application_id: applicationId,
      type: 'review',
      title: 'Review submitted application',
      due_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
      status: 'pending',
      priority: 'high'
    });
  
  // Send confirmation email to applicant
  await sendConfirmationEmail(applicationId);
}
```

---

## Security Considerations

1. **Webhook Signature Verification**: Always verify Stripe's signature to prevent fraudulent webhooks
2. **Idempotency**: Check payment status before processing to handle duplicate webhooks
3. **Service Role Authentication**: Use Supabase service role for webhook operations to bypass RLS
4. **Metadata Validation**: Validate all metadata extracted from Stripe events
5. **Transaction Atomicity**: Use database transactions to ensure data consistency

---

## Error Handling

```typescript
// Retry logic for failed webhooks
if (event.type === 'checkout.session.completed') {
  try {
    await processPayment(...);
  } catch (error) {
    console.error('Payment processing failed:', error);
    
    // Log error for manual review
    await supabase.from('payment_errors').insert({
      payment_request_id,
      error_message: error.message,
      stripe_event_id: event.id,
      created_at: new Date().toISOString()
    });
    
    // Stripe will retry webhook delivery automatically
    return Response.json({ error: 'Processing failed' }, { status: 500 });
  }
}
```

---

## Testing

### Test Mode

Use Stripe test mode with test card numbers:

- **Success**: `4242 4242 4242 4242`
- **Requires Authentication**: `4000 0025 0000 3155`
- **Declined**: `4000 0000 0000 9995`

### Webhook Testing

Use Stripe CLI to forward webhooks to localhost:

```bash
stripe listen --forward-to localhost:3000/api/webhooks/stripe
```

---

## Summary

This implementation ensures:

✅ **Secure payment processing** with webhook signature verification  
✅ **Idempotent operations** to handle duplicate webhooks safely  
✅ **Atomic transactions** for data consistency  
✅ **Automatic workflow advancement** after successful payment  
✅ **Comprehensive audit trail** for compliance and debugging  
✅ **Error handling and logging** for production reliability  

The architecture follows Stripe's best practices and ensures a robust, scalable payment system for the LearnLynk CRM.
