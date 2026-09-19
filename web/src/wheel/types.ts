/* ============================================================
 * The weapon wheel -- types
 *
 * ★ Everything here arrives from w_inventory through w_hud/client/wheel.lua as it is. The
 *   UI invents no number and computes no ammo: it shows what the inventory said, and sends
 *   the command back to it. (The reason is in w_hud/client/ammo.lua: the engine ammo pool
 *   is shared between two weapons, and only the inventory knows each instance's reserve.)
 * ============================================================ */

export type StatKey = 'damage' | 'range' | 'fireRate' | 'reload' | 'accuracy' | 'condition'

export interface AmmoOption {
  item: string
  ammo: string
  label: string
  /** What the player owns in the bag -- zero means shown and dimmed, not deleted */
  count: number
}

export interface WheelWeapon {
  slot: number
  name: string
  label: string
  hash: number
  serial?: string | number
  count: number

  oneHanded: boolean
  isGun: boolean
  throwable: boolean

  ammoname?: string
  family?: string
  /** What is chambered in this weapon alone */
  loaded: number
  capacity: number
  ammoItem?: string | null
  ammoOptions?: AmmoOption[]

  condition: number
  stats: Partial<Record<StatKey, number>>
  damageMultiplier: number

  held: boolean
  hand: number
  dualCapable: boolean

  /** Computed in Lua: the wheel class and the final bar values */
  class: string
  stats0: Record<string, number>
  /** Over the carry cap -- shown marked 'on the horse' */
  stowed?: boolean

  /** VORP only: the loadout row identifier -- for execution, not for display */
  weaponId?: number

  /**
   * The image filename without its extension, when it is not the item name.
   *
   * ★ RSG carries it in a separate field (item.image) because many items share one image.
   *   Where it does not exist, the name is used as before.
   */
  image?: string

  /**
   * Its position in the default list (0 or absent = not in it).
   *
   * ★ Computed in Lua deliberately: the stored key is a slot in our inventory and a loadout
   *   identifier on VORP, and the UI does not know the difference and should not.
   */
  quick?: number
}

export interface WheelSector {
  index: number
  role: string
  /** Degrees from the top of the screen, clockwise */
  angle: number
  sweep: number
  suit?: 'club' | 'diamond'
  mount?: 'back' | 'shoulder'
  cursor: number
  options: WheelWeapon[]
}

export interface WheelItem {
  slot: number
  name: string
  label: string
  count: number
  ammoFamily?: string
  usable?: boolean
  /** VORP only: the item identifier */
  itemId?: number
  /** The image filename without its extension, when it is not the item name (RSG) */
  image?: string
}

/**
 * What the active inventory supports.
 *
 * ★ The UI assumes nothing: it hides what the inventory lacks rather than drawing a button
 *   that does nothing or a bar with an invented value. (VORP stores neither weapon condition
 *   nor per-instance ammo types -- so no condition bar and no ammo switcher there.)
 */
export interface WheelCaps {
  condition: boolean
  clean: boolean
  ammoSwitch: boolean
  dual: boolean
  stow: boolean
}

export interface OilState {
  name: string
  label: string
  count: number
  required: number
  enabled: boolean
}

export interface WheelAssets {
  /**
   * Image folders as candidates, in order.
   *
   * ★ A list, not one path: every inventory puts its images in its own folder, so a fixed
   *   path means a wheel with eight empty discs on every server not running that inventory.
   *   The image fails and the next is tried (see ItemImage).
   */
  items: string | string[]
  tex: string
  sounds: string
  /** RDR2's own fist (a complete image, not a folder) */
  unarmed?: string
  /** The original dual-wield icon (a complete image, not a folder) */
  dualwield?: string
}

export interface WheelPayload {
  action: 'wheel:open'
  tab: 'weapons' | 'items' | 'horse'
  sectors: WheelSector[]
  items: WheelItem[]
  oil: OilState
  dual: { enabled: boolean; count: number; slots: number[] }
  /**
   * The default weapons in order -- a slot number as text, or 'dual', or 'unarmed'.
   * More than one: a TAB tap draws them all.
   */
  quick?: string[] | string | null
  assets: WheelAssets
  text: Record<string, string>
  order: StatKey[]
  ability: boolean
  rtl: boolean

  /** The active inventory's capabilities -- what is not there is not drawn */
  caps: WheelCaps
  /** Its name, for diagnostics: 'w_inventory' | 'vorp_inventory' | 'none' */
  bag: string
  /** Does left click holster (true) or equip as before (false) */
  stows: boolean
  /** And does the wheel close after holstering? By default no -- so several can be holstered in one opening */
  stowShut: boolean
}
