import React from 'react';
import cn from 'classnames';
import stl from './tabs.module.css';
import { Segmented } from 'antd';
import { Icon } from 'UI'

interface Props {
  tabs: Array<any>;
  active: string;
  onClick: (key: any) => void;
  border?: boolean;
  className?: string;
}

const iconMap = {
  "INSPECTOR": 'filters/tag-element',
  "CLICKMAP": 'mouse-pointer-click',
  'EVENTS': 'user-switch'
} as const

const Tabs = ({ tabs, active, onClick, border = true, className }: Props) => {
  console.log(tabs)
  return (
    <div className={cn(stl.tabs, className, { [stl.bordered]: border })} role="tablist">
      <Segmented
        value={active}
        options={tabs.map(({ key, text, hidden = false, disabled = false }) => ({
          label: (
            <div
              onClick={() => {
                onClick(key);
              }}
              className={'font-semibold flex gap-1 items-center'}
            >
              <Icon size={16} color={'black'} name={iconMap[key as keyof typeof iconMap]} />
              <span>{text}</span>
            </div>
          ),
          value: key,
          disabled: disabled,
        }))}
      />
      {/*{ tabs.map(({ key, text, hidden = false, disabled = false }) => (*/}
      {/*  <div*/}
      {/*    key={ key }*/}
      {/*    className={ cn(stl.tab, { [ stl.active ]: active === key, [ stl.disabled ]: disabled }) }*/}
      {/*    data-hidden={ hidden }*/}
      {/*    onClick={ onClick && (() => onClick(key)) }*/}
      {/*    role="tab"*/}
      {/*    data-openreplay-label={text}*/}
      {/*  >*/}
      {/*    { text }*/}
      {/*  </div>*/}
      {/*))}*/}
    </div>
  );
};

Tabs.displayName = 'Tabs';

export default Tabs;
