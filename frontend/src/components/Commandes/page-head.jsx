export const PageHead = (props)=>{


    return(
    <div className="page-head">
        <div>
          <div className="page-title">{props.title}</div>
          <div className="page-subtitle">{props.subtitle}</div>
        </div>
    </div>)

}