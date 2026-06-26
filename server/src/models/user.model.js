'use strict';

const mongoose = require('mongoose');

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/**
 * Account identity for auth. The password is never stored in the clear — only
 * the bcrypt hash, and it is excluded from query results by default
 * (`select: false`) so it cannot leak through a generic `.find()`.
 */
const userSchema = new mongoose.Schema(
  {
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      match: [EMAIL_RE, 'Invalid email address'],
    },
    passwordHash: {
      type: String,
      required: true,
      select: false,
    },
    displayName: {
      type: String,
      trim: true,
      maxlength: 80,
    },
  },
  { timestamps: true }
);

// Strip the hash from any serialized representation as a defense in depth,
// even if a query explicitly selects it.
userSchema.set('toJSON', {
  virtuals: true,
  transform(_doc, ret) {
    delete ret.passwordHash;
    delete ret.__v;
    return ret;
  },
});

module.exports = mongoose.models.User || mongoose.model('User', userSchema);
