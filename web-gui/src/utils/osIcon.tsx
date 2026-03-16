import type { ComponentType } from 'react';
import { FaLinux } from 'react-icons/fa';
import { SiRedhat, SiKalilinux, SiFedora, SiUbuntu, SiDocker } from 'react-icons/si';
import type { Asset } from '../types';

// Classic 4-color Windows flag (XP/Vista/7 era)
function ClassicWindowsIcon({ size = 36 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 88 88" xmlns="http://www.w3.org/2000/svg">
      <path fill="#f35325" d="M0 12.402l35.687-4.86.016 34.482-35.67.203z" />
      <path fill="#81bc06" d="M40.25 6.733l47.905-6.733.001 41.968-47.906.43z" />
      <path fill="#05a6f0" d="M35.67 45.387l.028 34.474L.028 75.082l-.028-29.765z" />
      <path fill="#ffba08" d="M40.161 45.522l47.894-.466.001 41.819-47.798-6.555z" />
    </svg>
  );
}

type SizedIcon = ComponentType<{ size?: number; color?: string }>;

type OsProfile = { icon: SizedIcon; color: string };

function getOsProfile(asset: Asset): OsProfile {
  const os       = asset.os.toLowerCase();
  const version  = (asset.os_version ?? '').toLowerCase();
  const isDocker = asset.tags?.includes('docker') ?? false;

  if (os.includes('windows')) return { icon: ClassicWindowsIcon, color: '' };

  if (os === 'linux') {
    if (isDocker)                   return { icon: SiDocker,    color: '#2496ED' };
    if (version.includes('rhel'))   return { icon: SiRedhat,    color: '#EE0000' };
    if (version.includes('kali'))   return { icon: SiKalilinux, color: '#367BF0' };
    if (version.includes('fedora')) return { icon: SiFedora,    color: '#51A2DA' };
    if (version.includes('ubuntu')) return { icon: SiUbuntu,    color: '#E95420' };
  }

  return { icon: FaLinux, color: '#FCC624' };
}

interface OsIconProps {
  asset: Asset;
  size?: number;
}

export function OsIcon({ asset, size = 36 }: OsIconProps) {
  const { icon: Icon, color } = getOsProfile(asset);
  return color ? <Icon size={size} color={color} /> : <Icon size={size} />;
}

// Section header / stats icons
export function WindowsIcon({ size = 24 }: { size?: number }) {
  return <ClassicWindowsIcon size={size} />;
}

export function LinuxIcon({ size = 24 }: { size?: number }) {
  return <FaLinux size={size} color="#FCC624" />;
}
