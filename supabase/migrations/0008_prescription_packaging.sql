alter table public.prescription_items 
  add column packaging_type text not null default 'box',
  add column unit_quantity integer not null default 1;

alter table public.prescription_items 
  add constraint prescription_items_packaging_type_check 
  check (packaging_type in ('box', 'strip', 'bottle', 'sachet', 'tube'));
