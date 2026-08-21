-- Enable UUID extension
create extension if not exists "pgcrypto";

-- ─── Profiles ───────────────────────────────────────────────────────────────
create table if not exists profiles (
  id             uuid references auth.users(id) on delete cascade primary key,
  username       text unique,
  display_name   text,
  avatar_url     text,
  bio            text,
  created_at     timestamptz default now()
);

-- Computed follower/following counts via view to avoid stale counters
create or replace view profiles_with_counts as
  select
    p.*,
    coalesce(f1.cnt, 0) as followers_count,
    coalesce(f2.cnt, 0) as following_count
  from profiles p
  left join (select following_id, count(*) as cnt from follows group by following_id) f1
    on f1.following_id = p.id
  left join (select follower_id, count(*) as cnt from follows group by follower_id) f2
    on f2.follower_id = p.id;

-- Auto-create profile row on new user sign-up
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id)
  values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ─── Follows ────────────────────────────────────────────────────────────────
create table if not exists follows (
  follower_id  uuid references auth.users(id) on delete cascade,
  following_id uuid references auth.users(id) on delete cascade,
  created_at   timestamptz default now(),
  primary key (follower_id, following_id)
);

-- ─── User Shows ─────────────────────────────────────────────────────────────
create table if not exists user_shows (
  id                     uuid default gen_random_uuid() primary key,
  user_id                uuid references auth.users(id) on delete cascade not null,
  show_id                integer not null,
  show_name              text not null,
  poster_path            text,
  status                 text default 'watching'
                           check (status in ('watching', 'up_to_date', 'finished', 'dropped')),
  current_season         integer default 1,
  current_episode        integer default 0,
  total_watched_episodes integer default 0,
  last_watched_at        timestamptz,
  created_at             timestamptz default now(),
  unique (user_id, show_id)
);

create index if not exists user_shows_user_id_idx on user_shows (user_id);

-- ─── User Episodes ───────────────────────────────────────────────────────────
create table if not exists user_episodes (
  id             uuid default gen_random_uuid() primary key,
  user_id        uuid references auth.users(id) on delete cascade not null,
  show_id        integer not null,
  season_number  integer not null,
  episode_number integer not null,
  watched_at     timestamptz default now(),
  unique (user_id, show_id, season_number, episode_number)
);

create index if not exists user_episodes_lookup_idx
  on user_episodes (user_id, show_id);

-- ─── User Movies ─────────────────────────────────────────────────────────────
create table if not exists user_movies (
  id          uuid default gen_random_uuid() primary key,
  user_id     uuid references auth.users(id) on delete cascade not null,
  movie_id    integer not null,
  movie_name  text not null,
  poster_path text,
  watched_at  timestamptz default now(),
  unique (user_id, movie_id)
);

create index if not exists user_movies_user_id_idx on user_movies (user_id);

-- ─── User Lists ──────────────────────────────────────────────────────────────
create table if not exists user_lists (
  id         uuid default gen_random_uuid() primary key,
  user_id    uuid references auth.users(id) on delete cascade not null,
  name       text not null,
  created_at timestamptz default now()
);

create table if not exists user_list_items (
  id       uuid default gen_random_uuid() primary key,
  list_id  uuid references user_lists(id) on delete cascade not null,
  show_id  integer,
  movie_id integer,
  added_at timestamptz default now(),
  constraint one_of_show_or_movie check (
    (show_id is not null) <> (movie_id is not null)
  )
);

-- ─── Row-Level Security ──────────────────────────────────────────────────────
alter table profiles         enable row level security;
alter table follows          enable row level security;
alter table user_shows       enable row level security;
alter table user_episodes    enable row level security;
alter table user_movies      enable row level security;
alter table user_lists       enable row level security;
alter table user_list_items  enable row level security;

-- profiles: public read, owner write
create policy "Public profiles are viewable by everyone"
  on profiles for select using (true);
create policy "Users can update own profile"
  on profiles for update using (auth.uid() = id);
create policy "Users can insert own profile"
  on profiles for insert with check (auth.uid() = id);

-- follows: authenticated read, owner write
create policy "Follows viewable by authenticated users"
  on follows for select using (auth.role() = 'authenticated');
create policy "Users manage own follows"
  on follows for all using (auth.uid() = follower_id);

-- user_shows: owner only
create policy "Users manage own shows"
  on user_shows for all using (auth.uid() = user_id);

-- user_episodes: owner only
create policy "Users manage own episodes"
  on user_episodes for all using (auth.uid() = user_id);

-- user_movies: owner only
create policy "Users manage own movies"
  on user_movies for all using (auth.uid() = user_id);

-- user_lists: owner only
create policy "Users manage own lists"
  on user_lists for all using (auth.uid() = user_id);
create policy "Users manage own list items"
  on user_list_items for all using (
    auth.uid() = (select user_id from user_lists where id = list_id)
  );
