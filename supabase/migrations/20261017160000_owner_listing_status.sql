-- Slice B. New listing lifecycle values.
-- This file only adds enum labels. The next migration uses them, which
-- PostgreSQL allows only after this transaction commits.
-- in_review: the owner submitted the draft and it is not live yet.
-- rented: the owner marked the home as let. It leaves the public feed.

alter type public.listing_status add value if not exists 'in_review';
alter type public.listing_status add value if not exists 'rented';
