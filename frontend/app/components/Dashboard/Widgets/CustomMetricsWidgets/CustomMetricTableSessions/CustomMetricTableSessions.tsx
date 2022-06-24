import { useObserver } from 'mobx-react-lite';
import React, { useEffect } from 'react';
import SessionItem from 'Shared/SessionItem';
import { Pagination, NoContent } from 'UI';
import { useModal } from 'App/components/Modal';

interface Props {
    metric: any;
    isTemplate?: boolean;
    isEdit?: boolean;
}

function CustomMetricTableSessions(props: Props) {
    const { isEdit = false, metric } = props;
    
    return useObserver(() => (
        <NoContent
            show={!metric || !metric.data || !metric.data.sessions || metric.data.sessions.length === 0}
            size="small"
        >
            <div className="pb-4">
                {metric.data.sessions && metric.data.sessions.map((session: any, index: any) => (
                    <div className="border-b last:border-none">
                        <SessionItem session={session} key={session.sessionId} />
                    </div>
                ))}
                
                {isEdit && (
                    <div className="mt-6 flex items-center justify-center">
                        <Pagination
                            page={metric.page}
                            totalPages={Math.ceil(metric.data.total / metric.limit)}
                            onPageChange={(page: any) => metric.updateKey('page', page)}
                            limit={metric.data.total}
                            debounceRequest={500}
                        />
                    </div>
                )}

                {!isEdit && (
                    <ViewMore total={metric.data.total} limit={metric.limit} />
                )}
            </div>
        </NoContent>
    ));
}

export default CustomMetricTableSessions;

const ViewMore = ({ total, limit }: any) => total > limit && (
    <div className="mt-4 flex items-center justify-center cursor-pointer w-fit mx-auto">
        <div className="text-center">
            <div className="color-teal text-lg">
                All <span className="font-medium">{total}</span> sessions
            </div>
        </div>
    </div>
);